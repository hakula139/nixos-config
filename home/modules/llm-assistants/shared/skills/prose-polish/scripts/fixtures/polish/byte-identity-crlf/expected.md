---
title: 本地检查的笔记
tags:
    - 记录检查配置的相关事项。
---

# Checks

  提交之前，需要检查配置。

Run the flake check before you push, since it utilizes the same hooks as CI.

提交之前，需要检查配置。
合并之前，也需要检查配置。

```text
head

    # 本地运行同样的检查

tail
```

- 运行检查的步骤：

  ```text
  head

  # 只在开发机上启用

  tail
  ```

```text
head
~~~

# 推送之前先运行全部检查
```


- 合并之前也需要检查配置。
