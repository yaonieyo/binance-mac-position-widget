# Binance Mac Position Widget

原生 macOS 菜单栏组件，默认以持仓为主，另提供可选的苹果风格桌面行情模式。

## 打开与运行

用 Xcode 打开 `BinancePositionWidget.xcodeproj`，选择 `BinancePositionWidget` scheme 后运行即可。

窗口首次启动会停在当前主屏幕右侧；顶部左侧抓手可以拖动窗口。右上角图钉可切换“始终置顶”，关闭后窗口回到桌面层。设置里的透明度支持 30%–100% 按 5% 调节，并会立即生效。

设置中的“显示方式”有两个选项：

- 持仓面板（默认）：优先显示真实持仓、浮盈和持仓详情。
- 桌面行情：切换为浅色/深色自动适配的苹果风格行情卡片。

窗口右上角三点菜单可以切换 Mock 布局场景（仅用于预览）：

- 0 仓：短空状态卡
- 1 仓：单仓短卡片
- 3 仓：多仓长卡片
- 8 仓：高度封顶并滚动

菜单栏还提供“适应内容高度”“始终置顶”“所有桌面显示”“重新连接”和退出等操作。

## 连接真实 Binance 账户

打开窗口右上角设置按钮或三点菜单，填入只读 API Key 和 API Secret，点击“保存并测试连接”。凭证只保存到 macOS Keychain，不写入项目文件和日志；连接成功后会加载真实 USDⓈ-M 持仓。

数据链路包括：

- REST 快照：Server Time、Account V3、Position Risk V3、Symbol Config，用于账户、持仓、杠杆、保证金模式和初始保证金。
- 公共行情 WebSocket：BTC、ETH、SOL、BNB 标记价格和 24 小时涨跌幅。
- 私有账户 WebSocket：账户/订单更新触发防抖后的 REST 快照刷新。
- 网络异常自动重连，失败时主面板和设置页会显示可读错误。

## 源码备份与敏感数据

Git 仓库仅保存 Swift 源码、Xcode 工程和项目说明。API 凭证由程序在运行时从 macOS Keychain 获取，不随源码分发。`work/`、`outputs/`、截图、日志、账户数据、环境变量文件及签名私钥均已加入忽略规则。

克隆后可运行 `git config core.hooksPath .githooks` 启用提交前检查，或运行 `bash scripts/check-staged-secrets.sh` 单独检查暂存内容。检查采用源码路径白名单并拦截常见凭证格式，报错仅显示文件名，不显示匹配值；它不能替代人工检查。
