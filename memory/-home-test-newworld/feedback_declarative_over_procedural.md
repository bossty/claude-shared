---
name: feedback-declarative-over-procedural
description: Owner 纠正——别过度设计：能用声明式结构（目录即配置）消除的逻辑，别写成"计算+enforce"的过程式脚本
metadata:
  node_type: memory
  type: feedback
  originSessionId: da3be312-2b73-46c3-95da-580bd268b069
---

声明式结构 > 过程式脚本。**能用一个结构（目录布局 / 配置文件 / 幂等同步）让逻辑变成不必要时，就别写"先算出 X、再 enforce X"的脚本。**

**Why（2026-05-17 Owner 当场纠正）**：OpenResty lua 部署治理，Claude 第一版方案是 `deploy-openresty-lua.sh` —— 硬编码每个 role 的 lua 模块清单 + nginx.conf require 闭包分析 + 逐文件 `cmp` 比对 + 循环检测孤儿。Owner："我感觉你把事情干得很复杂" —— 提出在仓库按 role 建**完整目录树**（`openresty/<role>/openresty/nginx/{conf,lua}/`），部署 = `rsync --delete` 同步目录。换成声明式后：role 定义 = 目录内容（肉眼可见、git diff 可审），孤儿清理 = `rsync --delete` 自带，**硬编码清单 / 闭包分析 / cmp / 孤儿检测循环全部消失**。那个过度设计的脚本直接删掉。过程式方案不仅代码多，还更脆——清单会与实际漂移、闭包会算错、cmp 是补丁。

**How to apply**：动手写"计算该有哪些 / 删掉多余的 / 比对差异"这类逻辑前，先停一拍问：**能不能用一个声明式结构让这套逻辑不必存在？** 典型信号 = 自己正在「硬编码一份清单」+「写检测/同步循环」——这通常是结构没选对的警铃。结构即真相（目录即 role 定义、`rsync --delete` 即同步语义）优于脚本算真相。先给 Owner 摆"声明式 vs 过程式"两个方案让其拍，而非默认上过程式。

**配套**：与 [[CLAUDE.md Lessons Learned]]「包装决策而非算法决策」同源（都是"别过度做"），但本条针对**方案结构设计**——不是过滤需求清单，是选声明式表示消解逻辑。
