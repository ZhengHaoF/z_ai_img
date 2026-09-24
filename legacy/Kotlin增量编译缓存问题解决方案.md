# Kotlin 增量编译缓存跨盘损坏问题

## 错误表现

在 Windows 上构建 Android 项目（Flutter / 原生 Android）时，Kotlin 编译阶段出现以下错误：

```
FAILURE: Build failed with an exception.

* What went wrong:
Could not close incremental caches in <build目录>\kotlin\compileReleaseKotlin\cacheable\caches-jvm\jvm\kotlin:
class-fq-name-to-source.tab, source-to-classes.tab, internal-name-to-source.tab

Caused by: java.lang.IllegalArgumentException:
this and base files have different roots:
<缓存盘>\...\SomeFile.kt
and
<项目盘>\...\android
```

**核心特征**：报错中出现 **"this and base files have different roots"**，涉及两个不同盘符的路径。

---

## 根本原因

| 项目 | 路径示例 | 盘符 |
|------|---------|------|
| 依赖缓存（源文件） | `C:\Users\<用户名>\.pub-cache\hosted\pub.dev\<包名>\...` | **C盘** |
| Gradle build 目录（编译缓存） | `D:\your-project\build\...` | **D盘** |

**Kotlin 增量编译器**在编译完成后关闭缓存时，需要将源文件路径转换为相对于 build 目录的相对路径。但 **Windows 不支持跨盘符的相对路径计算**（例如 `C:\` 和 `D:\` 之间无法用 `..\..\` 表示），导致抛出 `IllegalArgumentException: this and base files have different roots`。

### 为什么会发生？

- Windows 使用盘符（C:、D:、E: 等）隔离文件系统，不同盘符是独立的根目录
- Linux / macOS 只有一个根目录 `/`，不存在跨盘问题
- 当用户的依赖缓存（如 Flutter 的 Pub Cache、Gradle 的 Maven 缓存）在 C 盘，而项目在 D 盘（或其他盘）时就会触发
- 同一盘符下不会触发此问题

### 哪些场景容易遇到？

- **Flutter 项目**：Pub 默认缓存在 `C:\Users\<用户名>\.pub-cache` 或 `C:\Users\<用户名>\AppData\Local\Pub\Cache`，项目在 D 盘
- **Android 原生项目**：Gradle 的 Maven 缓存在 C 盘（`C:\Users\<用户名>\.gradle\caches`），项目在 D 盘
- **多盘符开发环境**：C 盘是系统盘、D 盘是工作盘的常见配置

---

## 解决方案

### 方案一：禁用 Kotlin 增量编译（最简单，推荐）

在 `android/gradle.properties` 中添加：

```properties
kotlin.incremental=false
```

**影响**：每次构建都会全量编译 Kotlin 代码，构建时间增加约 10-30 秒，但完全消除跨盘缓存错误。

**适用场景**：日常开发，想快速解决问题。

---

### 方案二：将依赖缓存移动到项目同一盘符（根本解决）

#### Flutter 项目

将 Pub 缓存从 C 盘移动到项目所在盘：

```powershell
# 1. 关闭所有 IDE 和终端

# 2. 移动缓存目录
Move-Item -Path "C:\Users\<用户名>\AppData\Local\Pub\Cache" -Destination "D:\pub-cache" -Force

# 3. 设置环境变量指向新位置
[Environment]::SetEnvironmentVariable("PUB_CACHE", "D:\pub-cache", "User")

# 4. 重启终端后验证
flutter pub cache list
```

#### Android 原生项目

将 Gradle 缓存从 C 盘移动到项目所在盘：

```powershell
# 1. 关闭所有 IDE 和终端

# 2. 移动缓存目录
Move-Item -Path "C:\Users\<用户名>\.gradle\caches" -Destination "D:\gradle-caches" -Force

# 3. 设置 GRADLE_USER_HOME 环境变量
[Environment]::SetEnvironmentVariable("GRADLE_USER_HOME", "D:\gradle", "User")

# 4. 重启终端后验证
gradle --version
```

**影响**：需要重新下载所有依赖包，占用空间数百 MB ~ 数 GB。

**适用场景**：长期项目，愿意一次性配置好。

---

### 方案三：彻底清理后重建（临时应急）

当缓存已损坏导致构建失败时，彻底清理：

```powershell
# 1. 关掉 Gradle 守护进程
cd android
.\gradlew --stop
cd ..

# 2. 删除所有构建目录（根据项目类型选择）
# Flutter 项目：
Remove-Item -Recurse -Force build, .dart_tool, android/.gradle, android/app/build

# Android 原生项目：
Remove-Item -Recurse -Force app/build, .gradle

# 3. 重新构建
flutter pub get && flutter build apk --release
# 或 Android 原生项目：
./gradlew assembleRelease
```

**影响**：仅临时解决，下次构建仍可能触发。

**适用场景**：紧急构建、临时应急。

---

## 三种方案对比

| 方案 | 操作难度 | 构建速度影响 | 是否根治 | 推荐场景 |
|------|----------|-------------|---------|---------|
| 禁用增量编译 | ⭐ 极简单 | 稍慢 10-30s | 是 | 日常开发，快速解决 |
| 移动缓存目录 | ⭐⭐ 中等 | 无影响 | 是 | 长期项目，一劳永逸 |
| 彻底清理重建 | ⭐ 简单 | 暂时解决 | 否 | 临时应急 |

---

## 常见路径参考

| 缓存类型 | 默认位置 | 对应环境变量 |
|---------|---------|------------|
| Flutter Pub 缓存 | `C:\Users\<用户名>\AppData\Local\Pub\Cache` | `PUB_CACHE` |
| Gradle 缓存 | `C:\Users\<用户名>\.gradle` | `GRADLE_USER_HOME` |
| npm 缓存 | `C:\Users\<用户名>\AppData\Local\npm-cache` | `npm_config_cache` |
| Maven 缓存 | `C:\Users\<用户名>\.m2` | `MAVEN_OPTS` |

---

## 补充说明

- **Linux / macOS 不受此影响**：只有一个根目录 `/`，不存在跨盘问题
- **同一盘符下不受影响**：如果 Pub 缓存和项目都在 C 盘，不会触发此错误
- **CI/CD 环境通常不受影响**：GitHub Actions、GitLab CI 等一般在同一盘符下构建
- **IDE 缓存也会受影响**：Android Studio / VS Code 的索引缓存如果跨盘也可能出类似问题，解决方式同上
