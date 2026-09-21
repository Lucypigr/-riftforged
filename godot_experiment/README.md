# Riftforged · Expedition Lab

獨立 Godot 4.7.2 / Compatibility 實驗版，基於 main `265bc9ec28187a2f04c30921dfee6f6f60755969`（PR #52）。
全部遊戲原始碼、場景、美術與測試都在此目錄內；不引用或改動 `godot_v2`，不使用原遊戲存檔位置。

## 啟動

從倉庫根目錄執行（需安裝 Godot 4.7.2）：

```sh
python3 godot_experiment/tools/prepare_font.py --project godot_experiment
godot --headless --path godot_experiment --import --quit
godot --path godot_experiment
```

或以 Godot 匯入本目錄的 `project.godot`，按 F6 執行 `main.tscn`。

## 操作與玩法

- WASD／方向鍵移動，左鍵普攻，1–5 使用快捷欄，Q/E 生命／魔力藥水。
- I 或背包按鈕開啟統一視窗；裝備、寶石／孔洞、快捷欄都在同一視窗內。
- 裝備頁：PC 拖曳；手機選物品再選裝備欄；長按約 0.45 秒查看名稱。
- 寶石頁：選寶石，再選同色已開孔；點已裝寶石的孔可拔下。通貨從擊殺掉落、靠近拾取取得。
- 快捷欄頁：選動作再選欄位，或依序點兩欄交換。手機大按鈕永遠是第 5 格。
- 手機左搖桿移動；方向技能及普攻按住瞄準、拖曳、放開施放；拖到取消區或被系統取消則不施放。
- 沿道路向北探索各區域，領主位於北方 Z=-124。M 查看地圖。死亡返回營地，裝備與地面掉落保留；領主同一局僅擊敗一次。
- 初始短弓串火球＋多重投射；其他流派透過打寶和換裝形成。沒有固定職業。

## 測試

```sh
python3 godot_experiment/tools/verify.py --godot godot
```

腳本逐一啟動真實遊戲場景，保留 logs / results.json 在 `reports/`，遇到執行錯誤亦判定失敗。
完整循環測試使用可控敵人位置／資源 fixture，實際經過技能傷害與 Boss 死亡流程；不代表人工通關、操作手感或裝置效能已驗證。

## Web 匯出

安装 Godot 4.7.2 export templates 後：

```sh
python3 -m pip install fonttools==4.61.1
python3 godot_experiment/tools/prepare_font.py --project godot_experiment
python3 godot_experiment/tools/subset_font.py
godot --headless --path godot_experiment --import --quit
mkdir -p godot_experiment/web
godot --headless --path godot_experiment --export-release Web "$PWD/godot_experiment/web/index.html"
python3 godot_experiment/tools/package_web.py godot_experiment/web
```

以 HTTP 靜態網站服務 `web/`。壓縮載入器使用瀏覽器 `DecompressionStream`，需新版 Safari／Chrome／Edge；Godot Web 仍需 WebGL 2。關閉多執行緒，無需 COOP/COEP。

目前為繼承既有素材與系統的功能實驗版，非重新製作的最終美術版本。詳細驗收與限制見 `docs/VALIDATION.md`。

## 寶石擴充
目前共 **57 顆寶石**（33 顆主動／光環、24 顆輔助）。新增旋風、餘震、箭雨、腐蝕地面、雷球、圖騰與召喚衛士等 18 顆主動及 12 顆輔助。
在背包的寶石頁選「流派搭配指南」可查看 23 種搭配及孔色；下方可搜尋已持有寶石。指南不會發放物品或自動換裝。新寶石由正常擊殺掉落，靠近拾取後再裝入同色連線孔。
技能均為原創簡化實作，具體差異見寶石說明；兩個指定參考網站本次回傳 403，未宣稱重現文章流派。
