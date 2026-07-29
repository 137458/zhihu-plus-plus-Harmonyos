/**
 * 详情页通用样式常量
 *
 * 原为本批次的占位页面组件（HdsNavigation 实现），但因 HdsNavigation 的
 * navDestination builder 约束（"HdsNavDestination 外只允许一层自定义组件，
 * 且自定义组件不允许设置属性和事件，否则仅显示空白"），详情页组件必须
 * build() 直接返回 HdsNavDestination，不能再包 PlaceholderPage。
 *
 * 故本文件改为导出详情页通用的 titleBar style 常量，供各详情页复用，
 * 避免 5 个详情页重复内联 30 行样式配置。
 *
 * 样式采用 HDS 模式三混合写法（4 字段组合）：
 *   1. scrollEffectOpts: ScrollEffectType.GRADIENT_BLUR（渐变模糊）
 *   2. systemMaterialEffect: MaterialType.IMMERSIVE + MaterialLevel.ADAPTIVE（沉浸光感材质）
 *   3. originalStyle: 滚动前样式（背景/文字/图标色）
 *   4. scrollEffectStyle: 滚动后样式（背景/文字/图标色）
 *
 * 渐变模糊立即生效（blurEffectiveEndOffset = 0vp），即使内容不滚动也有模糊效果。
 */

import { ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';

/**
 * 详情页 titleBar 的 style 配置。
 *
 * 各详情页在 .titleBar({ style: DETAIL_TITLE_BAR_STYLE, ... }) 中引用。
 * 类型不显式标注，由 ArkTS 推断字面量类型，确保与 HdsNavDestination
 * titleBar style 字段兼容。
 */
export const DETAIL_TITLE_BAR_STYLE: object = {
  scrollEffectOpts: {
    enableScrollEffect: true,
    scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
    blurEffectiveStartOffset: LengthMetrics.vp(0),
    blurEffectiveEndOffset: LengthMetrics.vp(0)
  },
  systemMaterialEffect: {
    materialType: hdsMaterial.MaterialType.IMMERSIVE,
    materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
  },
  originalStyle: {
    backgroundStyle: {
      backgroundColor: $r('app.color.app_title_bar_background')
    },
    contentStyle: {
      titleStyle: {
        mainTitleColor: $r('app.color.app_title_bar_on_surface'),
        subTitleColor: $r('app.color.app_on_surface_secondary')
      },
      menuStyle: {
        backgroundColor: $r('app.color.app_surface_variant'),
        iconColor: $r('app.color.app_title_bar_on_surface')
      },
      backIconStyle: {
        backgroundColor: $r('app.color.app_surface_variant'),
        iconColor: $r('app.color.app_title_bar_on_surface')
      }
    }
  },
  scrollEffectStyle: {
    backgroundStyle: {
      backgroundColor: $r('app.color.app_title_bar_background')
    },
    contentStyle: {
      titleStyle: {
        mainTitleColor: $r('app.color.app_title_bar_on_surface'),
        subTitleColor: $r('app.color.app_on_surface_secondary')
      },
      menuStyle: {
        backgroundColor: $r('app.color.app_surface_variant'),
        iconColor: $r('app.color.app_title_bar_on_surface')
      },
      backIconStyle: {
        backgroundColor: $r('app.color.app_surface_variant'),
        iconColor: $r('app.color.app_title_bar_on_surface')
      }
    }
  }
};

/**
 * 详情页 titleBar 的 padding 配置。
 */
export const DETAIL_TITLE_BAR_PADDING: object = {
  start: LengthMetrics.vp(2),
  end: LengthMetrics.vp(2)
};
