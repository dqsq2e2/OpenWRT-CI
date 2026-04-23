# QuickStart 温度显示修复说明

## 📝 问题描述

iStore 的 QuickStart 首页默认不显示 CPU 温度信息，这对于监控设备运行状态不太方便。

## ✨ 修复方案

本修复通过修改 `istore_backend.lua` 文件，在 QuickStart 的系统状态 API 响应中自动注入 CPU 温度数据。

## 🔧 技术实现

### 1. 温度读取函数

```lua
local function get_cpu_temperature()
  local temp_file = io.open("/sys/class/thermal/thermal_zone0/temp", "r")
  if temp_file then
    local temp = temp_file:read("*n")
    temp_file:close()
    if temp then
      return math.floor(temp / 1000)  -- 转换为摄氏度
    end
  end
  return 0  -- 如果读取失败，返回 0
end
```

### 2. API 拦截和修改

修复代码会拦截 `/istore/system/status/` API 请求，并在响应的 JSON 中注入温度数据：

```lua
-- 检查是否为 system/status 请求
local uri = http.getenv("REQUEST_URI")
local is_status_request = string.match(uri, "/istore/system/status/")

if is_status_request then
  -- 收集所有数据
  local chunks = {}
  -- ... 收集响应数据 ...
  
  -- 修改 JSON
  local json = table.concat(chunks)
  local cpu_temp = get_cpu_temperature()
  local modified_json = json:gsub('"result":{', 
    string.format('"result":{"cpuTemperature":%d,', cpu_temp))
  
  -- 发送修改后的数据
  http.write(modified_json)
end
```

### 3. 支持 Chunked 和非 Chunked 响应

修复代码同时支持两种 HTTP 传输编码：
- **Chunked Transfer Encoding**: 分块传输
- **Content-Length**: 固定长度传输

## 📦 文件说明

### 源文件位置
```
OpenWRT-CI-main/Files/istore/istore_backend.lua
```

### 目标位置
编译时会自动替换到：
```
feeds/*/luci-app-quickstart/*/istore_backend.lua
```

可能的路径：
- `feeds/istore/luci-app-quickstart/luasrc/controller/istore_backend.lua`
- `package/feeds/istore/luci-app-quickstart/luasrc/controller/istore_backend.lua`

## 🚀 使用方法

### 自动应用（推荐）

修复会在编译时自动应用，无需手动操作。编译脚本 `Settings-iStore.sh` 会：

1. 查找 `istore_backend.lua` 文件
2. 复制修复后的文件覆盖原文件
3. 验证文件是否正确替换

### 手动应用

如果需要在已编译的固件上手动应用：

```bash
# 1. 下载修复文件到路由器
scp istore_backend.lua root@192.168.1.1:/tmp/

# 2. 备份原文件
ssh root@192.168.1.1
cp /usr/lib/lua/luci/controller/istore_backend.lua \
   /usr/lib/lua/luci/controller/istore_backend.lua.bak

# 3. 替换文件
mv /tmp/istore_backend.lua /usr/lib/lua/luci/controller/istore_backend.lua

# 4. 重启 uhttpd
/etc/init.d/uhttpd restart

# 5. 清除浏览器缓存，刷新 QuickStart 页面
```

## 🌡️ 温度传感器说明

### 支持的设备

大多数现代 ARM/MIPS 路由器都支持温度传感器，包括：
- MediaTek MT7986/MT7981/MT7621 系列
- Qualcomm IPQ807x/IPQ60xx 系列
- Rockchip RK3568/RK3588 系列

### 检查温度传感器

```bash
# 检查是否存在温度传感器
ls -l /sys/class/thermal/thermal_zone*/temp

# 读取温度（单位：毫摄氏度）
cat /sys/class/thermal/thermal_zone0/temp
# 输出示例：45000（表示 45°C）

# 查看所有温度区域
for zone in /sys/class/thermal/thermal_zone*; do
  echo "$(basename $zone): $(cat $zone/temp)"
done
```

### 多温度区域

某些设备有多个温度传感器：
- `thermal_zone0`: CPU 温度
- `thermal_zone1`: WiFi 芯片温度
- `thermal_zone2`: 其他传感器

当前修复只读取 `thermal_zone0`（CPU 温度）。

## 🐛 故障排除

### 问题 1: 温度显示为 0°C

**可能原因：**
1. 设备不支持温度传感器
2. 温度传感器驱动未加载
3. 权限问题

**解决方法：**
```bash
# 检查温度文件是否存在
ls -l /sys/class/thermal/thermal_zone0/temp

# 检查文件权限
chmod 644 /sys/class/thermal/thermal_zone0/temp

# 检查内核模块
lsmod | grep thermal

# 手动读取温度
cat /sys/class/thermal/thermal_zone0/temp
```

### 问题 2: 修复未生效

**可能原因：**
1. 文件未正确替换
2. uhttpd 未重启
3. 浏览器缓存

**解决方法：**
```bash
# 1. 验证文件是否包含修复代码
grep "get_cpu_temperature" /usr/lib/lua/luci/controller/istore_backend.lua

# 2. 重启 uhttpd
/etc/init.d/uhttpd restart

# 3. 清除浏览器缓存
# Chrome: Ctrl+Shift+Delete
# Firefox: Ctrl+Shift+Delete
# 或使用无痕模式访问

# 4. 检查 Lua 错误日志
logread | grep lua
```

### 问题 3: QuickStart 页面报错

**可能原因：**
1. Lua 语法错误
2. 文件编码问题
3. 权限问题

**解决方法：**
```bash
# 1. 检查 Lua 语法
lua -c /usr/lib/lua/luci/controller/istore_backend.lua

# 2. 检查文件编码（应该是 UTF-8）
file /usr/lib/lua/luci/controller/istore_backend.lua

# 3. 恢复备份文件
cp /usr/lib/lua/luci/controller/istore_backend.lua.bak \
   /usr/lib/lua/luci/controller/istore_backend.lua
/etc/init.d/uhttpd restart
```

## 📊 API 响应示例

### 修复前
```json
{
  "code": 0,
  "result": {
    "hostname": "OpenWrt",
    "uptime": 12345,
    "memory": {...},
    "cpu": {...}
  }
}
```

### 修复后
```json
{
  "code": 0,
  "result": {
    "cpuTemperature": 45,  // 新增的温度字段
    "hostname": "OpenWrt",
    "uptime": 12345,
    "memory": {...},
    "cpu": {...}
  }
}
```

## 🔒 安全说明

1. **只读操作**: 修复代码只读取温度文件，不进行任何写操作
2. **错误处理**: 如果温度文件不存在或读取失败，返回 0 而不是报错
3. **性能影响**: 温度读取操作非常快（<1ms），对性能影响可忽略
4. **兼容性**: 不影响其他 API 请求，只修改 `/istore/system/status/` 响应

## 📚 参考资料

- [Linux Thermal Framework](https://www.kernel.org/doc/html/latest/driver-api/thermal/index.html)
- [OpenWrt Temperature Monitoring](https://openwrt.org/docs/guide-user/perf_and_log/temperature)
- [iStore 官方文档](https://github.com/linkease/istore)

## 🙏 致谢

- 原始修复方案来自 Actions-OpenWrt-MT798X-main 项目
- 感谢 LinkEase 团队开发 iStore
- 感谢 OpenWrt 社区的支持

## 📄 许可证

MIT License - 与主项目保持一致
