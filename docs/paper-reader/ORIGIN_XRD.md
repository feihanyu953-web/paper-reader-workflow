# Origin XRD 绘图自动化流程

适用场景：用户要求用 Origin/OriginPro 绘制 XRD 图，并加入 PDF/JCPDS 卡片峰位对照。本文档面向 Codex 和 Claude Code，目标是让后续代理可直接按步骤调用 Origin 生成可编辑 `.opju` 和导出图。

本流程来自 2026-06-03 `CEO2-C` XRD 绘图实测。关键结论是：不要依赖 Origin GUI 点击，也不要优先用 `impASC` 隐藏导入；推荐使用 Origin 命令行运行 OGS，OGS 再调用 Origin 内置 Python。

## 推荐路线

固定采用三段式：

1. 普通 Python 在工作区解析 XRD 数据和 PDF 卡片，生成纯英文临时目录中的数据文件。
2. Origin 命令行执行一个极短 OGS：

```labtalk
[Main]
run -pyf "C:\Users\<user>\AppData\Local\Temp\codex_origin_xrd_run\make_xrd_origin.py";
exit;
```

3. `make_xrd_origin.py` 在 Origin 内置 Python 中运行，使用 `originpro` API 写 workbook、创建 graph、保存 `.opju`、导出 `.png`。

不要把数据文件直接放在含中文路径的目录里让 Origin 导入。先复制/生成到英文临时目录，例如：

```text
%TEMP%\codex_origin_xrd_run\
```

## 已验证环境

- Origin：`Origin 2026 SR1`
- 可执行文件：`E:\Program Files\OriginLab\Origin2026\Origin64.exe`
- Origin 内置 Python：可通过 `run -pyf` 调用，且内置 Python 可 `import originpro`
- 工作区示例目录：

```text
E:\codex\文献阅读\博士课题\测试\XRD\2026-6-2
```

本次输出文件：

```text
CEO2-C_XRD_PDF43-1002_Origin.opju
CEO2-C_XRD_PDF43-1002_Origin.png
```

## 输入文件约定

同一目录下通常包含：

```text
<sample>.txt              # XRD 文本数据，含 [Data] 段
PDF#xx-xxxx.txt           # PDF/JCPDS 卡片文本
```

XRD 数据行示例：

```text
10.0164,       148,
10.0327,       156,
```

PDF 卡片峰位行示例：

```text
28.549  3.1240  100.0  ( 1 1 1)
```

解析后建议生成：

```text
<sample>_origin_xrd_data.csv
PDFxx-xxxx_<phase>_reference.csv
<sample>_PDFxx-xxxx_peak_match_report.csv
```

## 执行步骤

### 1. 检查 Origin 进程

先确认是否已有 Origin 进程：

```powershell
Get-Process | Where-Object { $_.ProcessName -match 'Origin' } |
  Select-Object ProcessName,Id,Path,MainWindowTitle,Responding,StartTime
```

如果存在无窗口标题、由本次自动化测试残留的 `Origin64` 进程，可在用户明确同意后关闭指定 PID：

```powershell
Get-Process -Id <PID1>,<PID2> | Stop-Process -Force
```

注意：不要擅自关闭用户可能正在编辑的 Origin 项目。关闭 Origin 可能丢失未保存工作，必须让用户确认。

### 2. 准备英文临时目录

```powershell
$tmp = Join-Path $env:TEMP 'codex_origin_xrd_run'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
```

把解析后的数据写入该目录，推荐 tab 分隔 ASCII 文件：

```text
xrd_data.dat
ceo2_sticks.dat
make_xrd_origin.py
run_make_xrd_origin.ogs
```

### 3. 用 Origin 内置 Python 绘图

`make_xrd_origin.py` 的核心结构：

```python
from pathlib import Path
import csv
import originpro as op

tmp = Path(r"C:\Users\<user>\AppData\Local\Temp\codex_origin_xrd_run")
xrd_path = tmp / "xrd_data.dat"
out_png = tmp / "sample_XRD_Origin.png"
out_opju = tmp / "sample_XRD_Origin.opju"

def read_numeric_table(path):
    with open(path, "r", newline="") as f:
        rows = list(csv.reader(f, delimiter="\t"))
    header = rows[0]
    cols = [[] for _ in header]
    for row in rows[1:]:
        if not row or not row[0]:
            continue
        for i, val in enumerate(row[:len(cols)]):
            cols[i].append(float(val))
    return header, cols

_, xrd_cols = read_numeric_table(xrd_path)

op.lt_exec("doc -n;")

wb = op.new_book("w", lname="XRD data")
wks = wb[0]
wks.cols = 3
wks.from_list(0, xrd_cols[0], lname="2theta", units="degree", axis="X")
wks.from_list(1, xrd_cols[1], lname="raw counts", axis="Y")
wks.from_list(2, xrd_cols[2], lname="Savitzky-Golay smooth", axis="Y")

gp = op.new_graph(lname="XRD PDF reference")
gl = gp[0]
p_raw = gl.add_plot(wks, coly=1, colx=0, type="l")
p_raw.set_cmd("-c 15", "-w 1")
p_raw.transparency = 45
p_smooth = gl.add_plot(wks, coly=2, colx=0, type="l")
p_smooth.set_cmd("-c 4", "-w 3")

gl.set_xlim(10, 91)
gl.set_ylim(0, 255)
gl.axis("x").title = "2theta (degree)"
gl.axis("y").title = "Intensity (counts)"

for x, rel_int, hkl in [
    (28.549, 100.0, "111"),
    (33.077, 27.0, "200"),
    (47.483, 46.0, "220"),
    (56.342, 34.0, "311"),
]:
    y = 6 + rel_int * 0.36
    line = gl.add_line(x, 0, x, y)
    line.color = (220, 60, 60)
    line.width = 2
    gl.add_label(hkl, x + 0.25, y + 3)

op.lt_exec('legend.text$ = "raw counts%(CRLF)Savitzky-Golay smooth";')
op.lt_exec("legend.x = 66; legend.y = 238;")

gp.save_fig(str(out_png), type="png", replace=True, width=2400)
op.save(str(out_opju))
```

### 4. 用 OGS 调用 Python

`run_make_xrd_origin.ogs`：

```labtalk
[Main]
run -pyf "C:\Users\<user>\AppData\Local\Temp\codex_origin_xrd_run\make_xrd_origin.py";
exit;
```

执行命令使用 `cmd /c start /wait`，这是本机已验证能正常运行的方式：

```powershell
$tmp = Join-Path $env:TEMP 'codex_origin_xrd_run'
$ogs = Join-Path $tmp 'run_make_xrd_origin.ogs'
$cmd = 'start /wait "" "E:\Program Files\OriginLab\Origin2026\Origin64.exe" -h -rs run.section("' + $ogs + '", main)'
cmd /c $cmd
```

执行完成后检查：

```powershell
Get-ChildItem -LiteralPath $tmp -Force |
  Sort-Object LastWriteTime -Descending |
  Select-Object Name,Length,LastWriteTime
```

### 5. 复制回用户目录

```powershell
$src = Join-Path $env:TEMP 'codex_origin_xrd_run'
$dst = 'E:\codex\文献阅读\博士课题\测试\XRD\2026-6-2'
Copy-Item -LiteralPath (Join-Path $src 'sample_XRD_Origin.png') -Destination $dst -Force
Copy-Item -LiteralPath (Join-Path $src 'sample_XRD_Origin.opju') -Destination $dst -Force
```

## 常见卡点

### Computer Use 不稳定

本次 `Computer Use` 在连接 Windows helper 时出现：

```text
windows sandbox failed: spawn setup refresh
```

因此不要把 Origin 绘图依赖于窗口点击。能用命令行和 Origin 内置 Python 时，优先使用命令行。

### 外部 Python 的 originpro 可能卡住

外部 Python 中：

```python
import originpro as op
op.set_show(True)
```

在本次环境里会卡在连接/启动 Origin 阶段。不要把外部 Python `originpro` 作为主路线。

### impASC 在隐藏命令行中可能卡住

以下写法在本机隐藏命令行中可能无输出卡住：

```labtalk
impASC;
impasc fname:="C:\...\xrd_data.dat";
```

因此推荐：在 Origin 内置 Python 中直接用 `wks.from_list()` 写列，而不是走文本导入器。

### 中文路径会增加失败概率

Origin 命令行和 LabTalk 对含中文路径、空格、引号的组合较脆弱。推荐所有自动化中间文件统一放在纯英文临时目录：

```text
%TEMP%\codex_origin_xrd_run\
```

最终产物再复制回中文工作目录。

### PDF stick pattern 不要用折线数据直接连

如果把参考峰写成：

```text
x, 0
x, y
blank, blank
```

Origin 有时仍会把 stick pattern 连成斜线。更稳的做法是用：

```python
gl.add_line(x, 0, x, y)
```

逐个峰画独立竖线。

## Claude Code 调用提示词

后续可直接给 Claude Code：

```text
请按 E:\codex\文献阅读\docs\paper-reader\ORIGIN_XRD.md 的流程，用 Origin 2026 绘制 XRD 图。
要求：
1. 不使用 Origin GUI 点击；
2. 不使用 impASC 作为主路线；
3. 先把数据和脚本放到 %TEMP%\codex_origin_xrd_run；
4. 用 Origin64.exe -h -rs run.section(...) 执行 OGS；
5. OGS 调 Origin 内置 Python run -pyf；
6. 用 originpro 的 wks.from_list / gl.add_plot / gl.add_line 生成图；
7. 输出 .opju 和 .png，并复制回原 XRD 目录；
8. 最后必须视觉检查 PNG，发现标题、图例、峰标、坐标轴重叠要修正后重导出。
```

## 质量检查

交付前必须检查：

- `.opju` 是否存在且大小不是 0。
- `.png` 是否存在且视觉可读。
- raw counts 与 smooth 曲线都在图中。
- PDF 卡片峰位为独立竖线，不出现斜线连接。
- 主要峰标不压住样品曲线。
- 图例不压边、不遮挡主峰。
- 坐标轴范围覆盖实验数据和主要参考峰。

本次 CeO2 PDF#43-1002 主峰：

```text
28.549 (111)
33.077 (200)
47.483 (220)
56.342 (311)
59.090 (222)
69.416 (400)
76.704 (331)
79.077 (420)
88.428 (422)
95.405 (511)
```

