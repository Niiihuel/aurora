#include "Rim.hpp"
#include "Shaders.hpp"

#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/desktop/Workspace.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/helpers/math/Math.hpp>
#include <hyprland/src/render/OpenGL.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/render/gl/GLFramebuffer.hpp>

#include <cmath>

using Render::GL::g_pHyprOpenGL;

namespace Aurora {

    // The material, in points: aurora's glass (shell/shaders/glass.frag)
    // with a light veil, since a rim this thin shows little behind it.
    constexpr float      REFRACTION = 8.f;
    constexpr float      DISPERSION = 0.4f;
    constexpr float      SATURATION = 2.f;
    constexpr float      GLINT      = 1.1f; // the focused window's edge light
    constexpr float      GLINT_IDLE = 0.4f; // everyone else's
    const CHyprColor     TINT{0x26 / 255.f, 0x26 / 255.f, 0x28 / 255.f, 0.15f};

    // How far a rim pixel's lookup can land from it, px: the bend tops out
    // at 1.02x the refraction and the farthest tap at 1.16x that, plus the
    // dispersion and a pixel of filtering.
    static float reach(float pxPerPoint) {
        return std::ceil((1.2f * REFRACTION + DISPERSION) * pxPerPoint) + 2.f;
    }

    // The window's box on this monitor, as Hyprland places its surface.
    static CBox windowBox(const PHLWINDOW& w) {
        const auto ws     = w->m_workspace;
        const auto offset = ws && !w->m_pinned ? ws->m_renderOffset->value() : Vector2D{};
        return {w->m_realPosition->value() + offset + w->m_floatingOffset, w->m_realSize->value()};
    }

    // --- decoration ---------------------------------------------------------

    SDecorationPositioningInfo CRimDecoration::getPositioningInfo() {
        // Nothing reserved: the rim takes the border's place, which already is.
        return {};
    }

    void CRimDecoration::draw(PHLMONITOR mon, float const& a) {
        const auto w = m_window.lock();
        if (!w || w->m_X11DoesntWantBorders || g_pHyprRenderer->type() != Render::IHyprRenderer::RT_GL)
            return;
        const int border = w->getRealBorderSize();
        if (border < 1)
            return;

        // Same rounding as CHyprBorderDecoration, so the rim meets the window exactly.
        const float s   = mon->m_scale;
        const CBox  win = windowBox(w).translate(-mon->m_position).scale(s).round();
        if (win.w < 1 || win.h < 1)
            return;
        const float thick = std::round(border * s);
        const float base  = w->rounding();
        const float power = w->roundingPower();

        SRim rim;
        rim.box           = win.copy().expand(thick);
        rim.thick         = thick;
        rim.radius        = base * s;
        rim.radiusOuter   = base > 0 ? (base + border - border * (M_SQRT2 - 1) * std::max(2.f - power, 0.f)) * s : 0.f;
        rim.roundingPower = power;
        rim.alpha         = a;
        rim.scale         = s;
        // Focus changes often, so it switches without motion (main.cpp repaints both rims).
        rim.focus = w == Desktop::focusState()->window() ? 1.f : 0.f;

        // One element per side, as deep as the rim plus its reach plus the
        // corner, so every pixel a side reads is inside that side's box.
        const CBox& b = rim.box;
        const float t = std::ceil(thick + reach(s) + rim.radius);
        if (b.w <= 2 * t || b.h <= 2 * t) {
            g_pHyprRenderer->addPassElement(makeUnique<CRimPassElement>(rim, b));
            return;
        }
        for (const CBox& strip : {CBox{b.x, b.y, b.w, t}, CBox{b.x, b.y + b.h - t, b.w, t}, CBox{b.x, b.y + t, t, b.h - 2 * t}, CBox{b.x + b.w - t, b.y + t, t, b.h - 2 * t}})
            g_pHyprRenderer->addPassElement(makeUnique<CRimPassElement>(rim, strip));
    }

    void CRimDecoration::damageEntire() {
        const auto w = m_window.lock();
        if (!Desktop::View::validMapped(w))
            return;
        const int border = w->getRealBorderSize();
        if (border < 1)
            return;
        const CBox box = windowBox(w).expand(border);
        CRegion    rg{box};
        rg.subtract(box.copy().expand(-(border + w->rounding() + 1)));
        g_pHyprRenderer->damageRegion(rg.expand(2));
    }

    // --- pass element -------------------------------------------------------

    std::vector<UP<IPassElement>> CRimPassElement::draw() {
        if (g_rims)
            g_rims->drawStrip(m_rim, m_strip);
        return {};
    }

    std::optional<CBox> CRimPassElement::boundingBox() {
        // monitor-local logical, as IPassElement wants; +1 for rounding.
        return m_strip.copy().scale(1.f / m_rim.scale).expand(1).round();
    }

    // --- GL -----------------------------------------------------------------

    CRims::~CRims() {
        if (!g_pHyprOpenGL)
            return;
        g_pHyprOpenGL->makeEGLCurrent();
        m_shader.reset();
        m_copies.clear();
    }

    void CRims::forget(MONITORID id) {
        if (g_pHyprOpenGL)
            g_pHyprOpenGL->makeEGLCurrent();
        m_copies.erase(id);
    }

    SP<Render::IFramebuffer> CRims::copyFor(PHLMONITOR mon) {
        const auto& target = g_pHyprRenderer->m_renderData.currentFB;
        if (target->m_size.x < 1 || target->m_size.y < 1)
            return nullptr;
        auto& fb = m_copies[mon->m_id];
        if (!fb)
            fb = g_pHyprRenderer->createFB("aurora-rims");
        if (!fb->alloc(target->m_size.x, target->m_size.y, target->m_drmFormat))
            return nullptr;
        return fb;
    }

    void CRims::drawStrip(const SRim& rim, const CBox& strip) {
        auto&      rd  = g_pHyprRenderer->m_renderData;
        const auto mon = rd.pMonitor.lock();
        if (!mon || rd.damage.empty() || !rd.currentFB || !rd.currentFB->getTexture())
            return;
        const auto target = dynamic_cast<Render::GL::CGLFramebuffer*>(rd.currentFB.get());
        if (!target)
            return;

        // Compiled here, where the EGL context is current; dynamic = fail
        // without asserting, silent = log ourselves.
        if (!m_shader && !m_shaderFailed) {
            auto shader = makeShared<CShader>();
            if (shader->createProgram(Shaders::VERT, Shaders::FRAG, true, true)) {
                m_shader    = shader;
                m_locOptics = glGetUniformLocation(shader->program(), "optics");
                m_locLight  = glGetUniformLocation(shader->program(), "light");
            } else {
                m_shaderFailed = true;
                Log::logger->log(Log::ERR, "[aurora-rims] the rim shader didn't compile; rims are off");
            }
        }
        if (!m_shader)
            return;

        CBox box = rim.box;
        CBox part = strip;
        rd.renderModif.applyToBox(box);
        rd.renderModif.applyToBox(part);
        const float k = rd.renderModif.combinedScale();
        if (box.w < 1 || box.h < 1)
            return;

        // The rim inside this strip and the damage; never the window's middle.
        CRegion    region = rd.damage.copy().intersect(part);
        const CBox hole   = box.copy().expand(-(rim.thick + rim.radius) * k);
        if (hole.w > 0 && hole.h > 0)
            region.subtract(hole);
        if (rd.clipBox.w != 0 && rd.clipBox.h != 0)
            region.intersect(rd.clipBox);
        if (region.empty())
            return;

        const auto copy = copyFor(mon);
        if (!copy)
            return;
        const auto copyFB = dynamic_cast<Render::GL::CGLFramebuffer*>(copy.get());
        if (!copyFB)
            return;

        // Copy what these rim pixels will read, then go back to the target.
        // The coordinates go through the same transform as Hyprland's scissor.
        g_pHyprRenderer->disableScissor();
        glBindFramebuffer(GL_READ_FRAMEBUFFER, target->getFBID());
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, copyFB->getFBID());
        const auto TR = Math::wlTransformToHyprutils(Math::invertTransform(mon->m_transform));
        region.copy().expand(reach(rim.scale * k)).intersect(CBox{{}, mon->m_transformedSize}).forEachRect([&](const auto& r) {
            CBox b{(double)r.x1, (double)r.y1, (double)(r.x2 - r.x1), (double)(r.y2 - r.y1)};
            if (rd.transformDamage)
                b.transform(TR, mon->m_transformedSize.x, mon->m_transformedSize.y);
            glBlitFramebuffer(b.x, b.y, b.x + b.w, b.y + b.h, b.x, b.y, b.x + b.w, b.y + b.h, GL_COLOR_BUFFER_BIT, GL_NEAREST);
        });
        glBindFramebuffer(GL_READ_FRAMEBUFFER, target->getFBID());
        target->bind();

        const bool blendBefore = glIsEnabled(GL_BLEND);
        g_pHyprOpenGL->blend(true);
        g_pHyprOpenGL->useShader(m_shader);

        const float px = rim.scale * k;
        m_shader->setUniformMatrix3fv(SHADER_PROJ, 1, GL_TRUE, g_pHyprRenderer->projectBoxToTarget(box).getMatrix());
        m_shader->setUniformInt(SHADER_TEX, 0);
        m_shader->setUniformFloat2(SHADER_FULL_SIZE, box.w, box.h);
        m_shader->setUniformFloat(SHADER_RADIUS, rim.radius * k);
        m_shader->setUniformFloat(SHADER_RADIUS_OUTER, rim.radiusOuter * k);
        m_shader->setUniformFloat(SHADER_ROUNDING_POWER, rim.roundingPower);
        m_shader->setUniformFloat(SHADER_THICK, rim.thick * k);
        m_shader->setUniformFloat4(SHADER_TINT, TINT.r, TINT.g, TINT.b, TINT.a);
        m_shader->setUniformFloat(SHADER_ALPHA, rim.alpha);
        if (m_locOptics != -1)
            glUniform4f(m_locOptics, REFRACTION * px, DISPERSION * px, px, rim.focus);
        if (m_locLight != -1)
            glUniform4f(m_locLight, SATURATION, GLINT, GLINT_IDLE, 0.f);

        const auto tex = copy->getTexture();
        glActiveTexture(GL_TEXTURE0);
        tex->bind();
        glBindVertexArray(m_shader->getUniformLocation(SHADER_SHADER_VAO));
        region.forEachRect([&rd](const auto& RECT) {
            g_pHyprOpenGL->scissor(&RECT, rd.transformDamage);
            glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        });
        glBindVertexArray(0);
        tex->unbind();
        g_pHyprOpenGL->blend(blendBefore);
    }
}
