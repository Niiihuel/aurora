// aurora-rims: a liquid glass rim on every window.
//
// The rim lives where Hyprland's border does (general.border_size wide), so
// layout, per-window rules, fullscreen and the border's damage and focus fade
// all keep working; the config makes the native border transparent and this
// decoration draws the glass under it.
//
// The glass refracts what is behind the window: the decoration sits on
// DECORATION_LAYER_UNDER, so when its pass element runs the framebuffer holds
// everything below the window but not the window itself. The element copies
// the part it needs into its own texture (a pass cannot sample the target it
// draws into) and draws the rim from that copy, bending the lookup inward the
// way a convex glass edge does.
//
// Each rim is four pass elements, one per side, because a pass element that
// samples what's below must say so (needsLiveBlur) and give a bounding box:
// Hyprland then repaints what's under that box and widens the damage around
// it. Four strips keep that to the window's edges instead of all of it.
#pragma once

#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/render/Framebuffer.hpp>
#include <hyprland/src/render/Shader.hpp>
#include <hyprland/src/render/decorations/IHyprWindowDecoration.hpp>
#include <hyprland/src/render/pass/PassElement.hpp>

#include <unordered_map>

namespace Aurora {

    struct SRim {
        CBox  box;               // outer edge of the rim, monitor-local px (window + rim on every side)
        float thick         = 0; // rim width, px
        float radius        = 0; // window corner radius, px
        float radiusOuter   = 0; // rim's outer corner radius, px
        float roundingPower = 2;
        float alpha         = 1;
        float focus         = 1; // 0 inactive … 1 focused
        float scale         = 1; // monitor px per point
    };

    class CRimPassElement : public IPassElement {
      public:
        CRimPassElement(const SRim& rim, const CBox& strip) : m_rim(rim), m_strip(strip) {}

        std::vector<UP<IPassElement>> draw() override;
        bool                          needsLiveBlur() override {
            return true;
        }
        bool needsPrecomputeBlur() override {
            return false;
        }
        std::optional<CBox> boundingBox() override;
        const char*         passName() override {
            return "AuroraRimPassElement";
        }
        ePassElementType type() override {
            return EK_CUSTOM;
        }

      private:
        SRim m_rim;
        CBox m_strip; // the part of the rim this element draws, monitor-local px
    };

    class CRimDecoration : public IHyprWindowDecoration {
      public:
        CRimDecoration(PHLWINDOW window) : IHyprWindowDecoration(window), m_window(window) {}

        SDecorationPositioningInfo getPositioningInfo() override;
        void                       onPositioningReply(const SDecorationPositioningReply&) override {}
        void                       draw(PHLMONITOR, float const& a) override;
        eDecorationType            getDecorationType() override {
            return DECORATION_CUSTOM;
        }
        void updateWindow(PHLWINDOW) override {}
        void damageEntire() override;
        eDecorationLayer getDecorationLayer() override {
            return DECORATION_LAYER_UNDER;
        }
        uint64_t getDecorationFlags() override {
            return DECORATION_NON_SOLID;
        }
        std::string getDisplayName() override {
            return "aurora rim";
        }

      private:
        PHLWINDOWREF m_window;
    };

    // GL state shared by every rim: the program and one copy of the scene per monitor.
    class CRims {
      public:
        ~CRims();
        void drawStrip(const SRim& rim, const CBox& strip);
        void forget(MONITORID id);

      private:
        SP<Render::IFramebuffer> copyFor(PHLMONITOR mon);

        SP<CShader>                                         m_shader;
        bool                                                m_shaderFailed = false;
        GLint                                               m_locOptics    = -1;
        GLint                                               m_locLight     = -1;
        std::unordered_map<MONITORID, SP<Render::IFramebuffer>> m_copies;
    };

    inline UP<CRims> g_rims;
}
