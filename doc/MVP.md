# Wrap - iOS SSH 终端应用 MVP 方案

## Context

在 iOS 上构建一个 SSH 终端工具，用户可以保存远程服务器连接信息（地址、端口、用户名、密码），一键连接并获得完整的终端体验（支持 vim、htop 等 TUI 应用）。

---

## 技术选型

| 组件 | 方案 | 理由 |
|------|------|------|
| 终端模拟器 | **SwiftTerm** | VT100/Xterm 兼容，纯 Swift，商用验证（Secure Shellfish, La Terminal） |
| SSH 协议 | **swift-nio-ssh** | Apple 官方维护，纯 Swift，SwiftTerm 示例已集成 |
| 数据持久化 | **SwiftData** | 项目已配置，存储服务器元信息 |
| 凭据存储 | **iOS Keychain** | 密码/密钥安全存储，不经过 SwiftData |
| UI | **SwiftUI (iOS 26)** | 使用 Liquid Glass 等 iOS 26 原生控件 |

**SPM 依赖：**
- `https://github.com/migueldeicaza/SwiftTerm.git`
- `https://github.com/apple/swift-nio-ssh.git`

### iOS 26 原生特性使用计划

| 特性 | 应用场景 |
|------|----------|
| **Liquid Glass (`.glassEffect()`)** | 终端页工具栏、服务器列表导航栏，半透明毛玻璃效果 |
| **ToolbarSpacer** | 终端工具栏按钮分组布局（关闭按钮 ← 间距 → 状态指示） |
| **Scroll Edge Blur** | 服务器列表滚动时工具栏自动模糊过渡 |
| **TabView + .search role** | 若后续增加多 Tab（服务器 / 历史 / 设置），使用原生搜索 Tab |
| **原生 NavigationStack** | 服务器列表导航，自动获得 Liquid Glass 导航栏 |
| **原生 Form / Section** | 添加服务器表单，自动 Liquid Glass 分组样式 |
| **`.searchable()`** | 服务器搜索，原生搜索栏集成 |
| **Context Menu** | 长按服务器行的操作菜单 |
| **`.fullScreenCover`** | 终端全屏展示 |
| **SecureField** | 密码输入 |
| **`@AppStorage`** | 用户偏好设置持久化 |

> **原则**：重新编译即可获得 Liquid Glass 新设计，无需额外代码。仅在需要精细控制时使用 `.glassEffect()` API。

---

## 目录结构

```
Wrap/
  WrapApp.swift                    (修改 - 更新 schema 和根视图)
  Models/
    ServerConnection.swift         (服务器连接模型)
    AuthMethod.swift               (认证方式枚举)
  Services/
    KeychainService.swift          (Keychain 封装)
    SSHService.swift               (SSH 会话管理)
    SSHChannelHandler.swift        (NIO Channel Handler)
  Views/
    ServerListView.swift           (主屏 - 服务器列表)
    ServerFormView.swift           (添加/编辑服务器)
    TerminalSessionView.swift      (终端会话页面)
    TerminalRepresentable.swift    (SwiftTerm UIViewRepresentable)
```

**删除：** `Item.swift`、`ContentView.swift`（模板文件）

---

## UI/UX 详细设计

### 1. 服务器列表（主屏 - ServerListView）

**使用的 iOS 26 原生控件：**
- `NavigationStack` → 自动 Liquid Glass 导航栏
- `.searchable()` → 原生搜索栏
- `List` + `Section` → 原生分组列表（自动 Liquid Glass 样式）
- `.swipeActions` → 原生左滑操作
- `.contextMenu` → 原生长按菜单
- `ContentUnavailableView` → iOS 17+ 原生空状态视图

```
┌─────────────────────────────────┐
│  Wrap                      [+]  │  ← NavigationStack + .navigationTitle
├─────────────────────────────────┤
│  🔍 Search servers...           │  ← .searchable() 原生搜索
├─────────────────────────────────┤
│  RECENT                         │  ← 最近连接（自动生成区）
│  ┌─────────────────────────────┐│
│  │ 🟢 Production API           ││  ← 绿点=上次成功 / 灰点=从未连接
│  │    root@192.168.1.100:22    ││  ← 副标题：user@host:port
│  │    Last: 2 hours ago      > ││  ← 上次连接时间 + 箭头导航
│  └─────────────────────────────┘│
│                                 │
│  WORK                           │  ← 自定义分组
│  ┌─────────────────────────────┐│
│  │ ○ Dev Server                ││
│  │    dev@10.0.0.5:22          ││
│  │    Never connected        > ││
│  ├─────────────────────────────┤│
│  │ ○ Staging                   ││
│  │    deploy@staging.app:2222  ││
│  │    Last: 3 days ago       > ││
│  └─────────────────────────────┘│
│                                 │
│  PERSONAL                       │
│  ┌─────────────────────────────┐│
│  │ ○ Home NAS                  ││
│  │    admin@nas.local:22       ││
│  │    Last: 1 week ago       > ││
│  └─────────────────────────────┘│
└─────────────────────────────────┘
```

**交互细节：**
- **点击服务器行** → 全屏打开终端（`.fullScreenCover`），最大化终端面积
- **左滑服务器行** → 显示「编辑」和「删除」操作
- **长按服务器行** → Context menu：复制地址、编辑、复制为 SSH 命令、删除
- **"Recent" 分组** → 自动聚合 `lastConnectedAt != nil` 的服务器，按时间倒序，最多显示 3 个
- **空状态** → 列表为空时显示引导：图标 + "Add your first server" + 大号添加按钮
- **搜索** → `.searchable()` 同时匹配 name、host、username
- **空状态** → 使用原生 `ContentUnavailableView`（iOS 17+）而非自定义视图

### 2. 添加/编辑服务器（ServerFormView）

**使用的 iOS 26 原生控件：**
- `Form` + `Section` → 原生表单分组（自动 Liquid Glass）
- `TextField` / `SecureField` → 原生输入
- `Picker` → 原生选择器
- `.sheet()` → 原生半屏/全屏弹出
- `.toolbar` → 原生导航栏按钮（Cancel / Save）

```
┌─────────────────────────────────┐
│  Cancel    Add Server     Save  │  ← 导航栏
├─────────────────────────────────┤
│                                 │
│  SERVER                         │
│  ┌─────────────────────────────┐│
│  │ Name          [My Server  ] ││  ← 显示名称
│  │ Host          [192.168.1.1] ││  ← .keyboardType(.URL), 不自动大写
│  │ Port          [22         ] ││  ← .keyboardType(.numberPad), 默认 22
│  └─────────────────────────────┘│
│                                 │
│  AUTHENTICATION                 │
│  ┌─────────────────────────────┐│
│  │ Method     [Password    |▼] ││  ← Picker: Password / Private Key
│  │ Username      [root       ] ││  ← .textInputAutocapitalization(.never)
│  │ Password      [••••••••   ] ││  ← SecureField
│  └─────────────────────────────┘│
│                                 │
│  ORGANIZATION                   │
│  ┌─────────────────────────────┐│
│  │ Group         [Work     |▼] ││  ← 下拉选择已有分组 或 输入新分组
│  └─────────────────────────────┘│
│                                 │
│  [🔴 Delete Server]            │  ← 仅编辑模式显示，红色确认
│                                 │
└─────────────────────────────────┘
```

**交互细节：**
- 以 `.sheet` 方式弹出（半屏/全屏自适应）
- Save 按钮在 name/host/username/password 全部非空时才启用
- 分组选择：Picker 列出所有已存在的分组 + "New Group..." 选项
- 编辑模式下预填所有字段（密码从 Keychain 加载）
- 密码字段右侧有小眼睛图标切换明文/密文

### 3. 终端会话（TerminalSessionView）

**使用的 iOS 26 原生控件：**
- `.fullScreenCover` → 原生全屏覆盖
- `.toolbar` + `ToolbarSpacer` → iOS 26 工具栏布局分组
- `.glassEffect()` → 工具栏 Liquid Glass 半透明效果
- `ProgressView` → 原生连接中动画
- `.alert()` → 原生断开确认弹窗
- `.overlay()` → 原生浮层（断开重连提示）
- `.persistentSystemOverlays(.hidden)` → 隐藏 Home Indicator

```
┌─────────────────────────────────┐
│ [✕]  Production API    🟢 Connected │  ← 紧凑工具栏
├─────────────────────────────────┤
│                                 │
│  $ ssh root@192.168.1.100       │
│  Welcome to Ubuntu 22.04       │
│  root@server:~#                │
│                                 │
│  (SwiftTerm TerminalView)      │
│  全屏渲染区域                    │
│  支持滚动回看                    │
│                                 │
│                                 │
│                                 │
│                                 │
│                                 │
├─────────────────────────────────┤
│ [ESC][Tab][Ctrl][↑][↓][←][→][-]│  ← 辅助按键栏（SwiftTerm 内置）
├─────────────────────────────────┤
│       iOS 软键盘区域             │
└─────────────────────────────────┘
```

**交互细节：**
- **全屏模式**（`.fullScreenCover`）：隐藏 Home Indicator，最大化终端面积
- **工具栏**：最小化高度，左侧关闭按钮 [✕]，中间服务器名称，右侧连接状态指示
- **连接状态指示**：
  - 🟢 Connected（绿色）
  - 🟡 Connecting...（橙色，带 ProgressView 旋转）
  - 🔴 Disconnected（红色）
- **断开重连**：连接断开时显示浮层 overlay：「Connection lost. [Reconnect] [Close]」
- **关闭确认**：点击 [✕] 时如果仍在连接中，弹出确认 Alert：「Disconnect from {name}?」
- **键盘处理**：
  - SwiftTerm 内置辅助按键栏（ESC、Tab、Ctrl、方向键）
  - `.ignoresSafeArea(.keyboard)` 确保终端随键盘调整
  - 支持外接键盘全部功能键
- **终端外观**：
  - 背景色：纯黑 `#000000`
  - 字体：`UIFont.monospacedSystemFont(ofSize: 14)`
  - 支持 256 色（xterm-256color）

### 4. 连接失败状态

```
┌─────────────────────────────────┐
│ [✕]  Production API   🔴 Failed │
├─────────────────────────────────┤
│                                 │
│                                 │
│         ⚠️                      │
│    Connection Failed            │
│                                 │
│    Could not connect to         │
│    192.168.1.100:22             │
│                                 │
│    Error: Connection refused    │
│                                 │
│    [  Retry  ]   [  Edit  ]     │
│                                 │
│                                 │
└─────────────────────────────────┘
```

- Retry：重新连接
- Edit：打开 ServerFormView 编辑此服务器信息

### 5. 空状态（首次打开 App）

使用原生 `ContentUnavailableView`（iOS 17+ 内置空状态组件）：

```swift
ContentUnavailableView {
    Label("No Servers", systemImage: "server.rack")
} description: {
    Text("Add a server to get started.")
} actions: {
    Button("Add Server") { showingAddServer = true }
        .buttonStyle(.borderedProminent)
}
```

```
┌─────────────────────────────────┐
│  Wrap                           │
├─────────────────────────────────┤
│                                 │
│         🖥️                      │
│     No Servers                  │  ← ContentUnavailableView
│  Add a server to get started.   │
│     [ Add Server ]              │  ← .borderedProminent 按钮
│                                 │
└─────────────────────────────────┘
```

### 6. 导航流程

```
App Launch
    │
    ▼
ServerListView (主屏)
    │
    ├── [+] 按钮 → ServerFormView (sheet, 添加)
    │                    │
    │                    └── Save → 返回列表
    │
    ├── 点击服务器 → TerminalSessionView (fullScreenCover)
    │                    │
    │                    ├── 连接成功 → 交互式终端
    │                    ├── 连接失败 → 错误页（Retry / Edit）
    │                    └── [✕] → 断开确认 → 返回列表
    │
    └── 左滑 → Edit → ServerFormView (sheet, 编辑)
              Delete → 确认删除
```

### 7. 设计原则

- **原生优先**：全部使用 iOS 26 原生控件，重编译即获 Liquid Glass 新设计，不自定义外观
- **一键连接**：从列表到终端只需一次点击，不弹额外确认
- **终端优先**：终端全屏显示，工具栏极简，把空间留给内容
- **安全无感知**：密码存 Keychain 自动加载，用户无需重复输入
- **快速恢复**：断开时提供重连选项，而非直接关闭
- **信息密度**：服务器列表每行显示 name + user@host:port + 上次连接，一眼识别

### 8. iOS 26 原生控件总览

| 页面 | 原生控件 |
|------|----------|
| 服务器列表 | `NavigationStack`, `List`, `Section`, `.searchable()`, `.swipeActions`, `.contextMenu`, `ContentUnavailableView` |
| 添加/编辑 | `Form`, `Section`, `TextField`, `SecureField`, `Picker`, `.sheet()`, `.toolbar` |
| 终端会话 | `.fullScreenCover`, `.toolbar`, `ToolbarSpacer`, `.glassEffect()`, `ProgressView`, `.alert()`, `.overlay()` |
| 连接失败 | `ContentUnavailableView`（复用空状态组件显示错误） |

---

## 实现步骤

### Step 1: 添加 SPM 依赖
在 Xcode 中添加 SwiftTerm 和 swift-nio-ssh 包。

### Step 2: 数据模型

**`Models/AuthMethod.swift`** - 认证方式枚举（password / privateKey），Codable。

**`Models/ServerConnection.swift`** - SwiftData @Model：
- `id: UUID`（同时作为 Keychain 查找键）
- `name, host, port, username, authMethod, group`
- `createdAt, lastConnectedAt`
- 密码**不存储在此模型中**，仅通过 id 关联 Keychain

### Step 3: Keychain 服务

**`Services/KeychainService.swift`** - 使用 Security 框架：
- `save(credential:for:)` / `load(for:)` / `delete(for:)`
- service = `"com.luzhan.Wrap.ssh"`，account = UUID string

### Step 4: SSH 通道处理器

**`Services/SSHChannelHandler.swift`** - NIO `ChannelDuplexHandler`：
- 接收 `SSHChannelData` → 解包为 bytes → 通过 `onData` 回调到主线程
- 提供 `send(_ data: Data)` 方法向远端写入
- 提供 `sendWindowChange(cols:rows:)` 处理终端大小变化

### Step 5: SSH 服务

**`Services/SSHService.swift`** - `@MainActor ObservableObject`：
- 状态管理：disconnected → connecting → connected → failed
- `connect()`: NIO bootstrap → SSH 握手 → 认证 → 请求 PTY(xterm-256color) → 开启 shell
- `disconnect()`: 关闭 channel 和 event loop group
- MVP 阶段使用 accept-all 的 host key 验证（后续添加 known_hosts）

### Step 6: 终端视图桥接

**`Views/TerminalRepresentable.swift`** - UIViewRepresentable：
- 创建 SwiftTerm `TerminalView`，设置等宽字体
- Coordinator 实现 `TerminalViewDelegate`：
  - `send(source:data:)` → 用户输入转发到 SSH
  - `sizeChanged(source:newCols:newRows:)` → SSH window-change 请求
- 连接时：SSH 输出 → `terminalView.feed(byteArray:)` 渲染

### Step 7: 终端会话页

**`Views/TerminalSessionView.swift`**：
- 黑色全屏背景 + TerminalRepresentable
- 顶部工具栏显示连接状态
- onAppear 从 Keychain 加载凭据

### Step 8: 服务器表单

**`Views/ServerFormView.swift`**：
- Form 表单：名称、主机、端口、用户名、密码、分组
- 支持密码和私钥两种认证方式
- 保存时：SwiftData 存元信息，Keychain 存凭据

### Step 9: 服务器列表（主屏）

**`Views/ServerListView.swift`**：
- 按分组显示服务器列表，支持搜索
- 点击服务器 → `fullScreenCover` 打开终端
- 支持滑动删除、添加按钮

### Step 10: 更新 App 入口

**`WrapApp.swift`**：
- Schema 改为 `[ServerConnection.self]`
- 根视图改为 `ServerListView()`

---

## 数据流

```
用户输入 → TerminalViewDelegate.send() → SSHShellHandler.send() → SSH Channel → 远程服务器
远程输出 → SSH Channel → SSHShellHandler.onData → terminalView.feed() → 屏幕渲染
窗口变化 → sizeChanged() → SSHShellHandler.sendWindowChange() → SSH window-change 请求
```

---

## 并发注意事项

项目设置 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`，所有类型默认 MainActor 隔离。NIO handler 需要在 NIO event loop 上运行，需用 `@preconcurrency import` 或 `nonisolated` 标注处理。

---

## MVP 范围

**包含：**
- 密码认证连接 SSH
- 完整终端模拟（支持 TUI）
- 服务器信息 CRUD
- Keychain 安全存储
- 分组和搜索

**不包含（后续迭代）：**
- 私钥认证（PEM 解析需额外工作）
- Host key 验证（MVP 用 accept-all）
- 多会话/标签页
- SFTP 文件浏览
- 端口转发
- 生物识别解锁
- iCloud 同步

---

## 验证方式

1. 添加 SPM 依赖后确认项目编译通过
2. 创建数据模型后在 ServerFormView 中添加一个测试服务器，确认 SwiftData 持久化正常
3. 实现 SSH 服务后，硬编码一个测试服务器连接，验证认证和 shell 交互
4. 集成 SwiftTerm 后，验证终端渲染、键盘输入、TUI 应用（运行 `top` 或 `vim`）
5. 完整 UI 后，端到端测试：添加服务器 → 点击连接 → 终端操作 → 断开
