# 启动页

在“设置 → 外观 → 动画与触感 → 启动动画”选择四种模式，
下次冷启动生效，默认保留“灵动开场”。模式和速度均持久化，并归入华为云同步的外观偏好。

- **直接进入**：不显示应用内图标或启动动画，直接创建首页。
- **保持图标**：显示默认图标，首页就绪后用 180 ms 淡出，不缩放。
- **iOS 风格**：图标保持至少 420 ms，首页就绪后轻缩至 0.82 倍，
  再放大并淡出背景，露出下面已经刷新的首页。仅动画 transform/opacity。
- **灵动开场**：按浅色或深色主题播放默认图标的本地开场动画，
  结束且首页就绪后淡出，末帧静图保持衔接。选中时可调播放速度：
  0.5×、0.75×、1×、1.25×、1.5×、1.75×、2×，默认 1×；其他模式隐藏此项。
  使用 Video 原生 `currentProgressRate`，不影响帖子视频或其他动画。

`pages/Startup` 仅提供轻量首帧，首个空闲帧或 32 ms 兜底立即通过
`UIContext.getRouter().replaceUrl` 替换为 `pages/Index`。动画在首页遮罩中播放，
因此账号恢复、缓存读取、首页刷新与动画并行，不再等视频播完才创建首页。
已渲染的首页帖子或本轮加载结束（含空数据/失败）允许退场。网络慢或离线时，
原生两种模式最多等 2200 ms，灵动开场的播放器看门狗为 `2500 / 倍速 + 1500 ms`，
遮罩额外保留 180 ms 退场时间（1× 时分别为 4000/4180 ms，0.5× 时为 6500/6680 ms）兜底
退出，随后显示首页原有的加载/空态/错误界面。减少动态效果时动画模式显示静态图标，
首帧后直接退出；切到后台、销毁或返回键退出时不会遗留遮罩计时器。

启动页不发起网络请求，不等待帖子、账号接口或推荐配置。应用在后台停留超过
10 分钟后重新进入前台会触发一轮缓存开屏；10 分钟内返回不显示。OAuth 回调和
跨设备恢复仍走原入口。返回键可以
提前结束首页遮罩。引导页和推荐弹窗等待遮罩移除后再展示。

`module.json5` 必填的 `startWindowIcon` 指向 `start_window_empty.svg`，只保留
系统启动窗口的浅色/深色背景。系统的桌面展开动效仍由系统负责，所选动画从
首页遮罩接管画面。后台返回的缓存开屏不重播冷启动动画。

## 修改画面

- `components/StartupAnimation.ets`：静音播放本地动画，末帧用于首页衔接。
- `utils/StartupAnimationSource.ets`：根据主题选择默认图标的浅色或深色视频。
- `resources/rawfile/startup/`：默认图标的两段视频及对应末帧静图。
- `startup_animation_size` 和 `startup_animation_*`：动画容器尺寸与背景色。
- `utils/StartupSession.ets`：展示时间和一次性遮罩状态。
- `services/StartupSettingsStore.ets`：四种模式、七档速度的持久化与非法值回退。

“直接进入”跳过品牌动画层；缓存推荐开屏仍按独立规则判断。

背景色按视频**原始分辨率解码后的外圈 10% 主色**取值，不平均 Logo 像素，
也不先缩放 YUV 视频再取色。浅色背景为 `#FBFDFA`，深色背景为 `#000000`。
两段 H.264 视频的 MP4 容器与码流都标注 BT.601（SMPTE 170M，limited range）。
`scripts/verify-startup-video-backgrounds.py` 核对视频、末帧和背景资源，
用 `--report docs/startup-video-backgrounds.json` 生成验证记录。
元数据核验及软件解码不能替代真机硬件播放的视觉验收。

路由替换失败时启动页显示现有的“重试”按钮；启动页资源加载失败时
EntryAbility 自动回退到首页。组件销毁会清理计时器并忽略过期帧回调。

测试：`node --test tests/startup-page.test.cjs tests/notification-launch.test.cjs tests/home-exit-confirmation.test.cjs tests/huawei-account-cloud.test.cjs`。
