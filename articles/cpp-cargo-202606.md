---
title: "CMakeが嫌なのでC/C++版Cargoを作っている話"
emoji: "🐥"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["c", "cpp", "cargo", "個人開発", "cmake"]
published: false
---

## TL;DR

C/C++開発には必要なツールが多いです。CMake, Ninja, vcpkg, Conan, pkg-config, clang-format, clang-tidy...。
普段Rustを使って開発をしていく中で、Rustの`cargo build`のような体験をC/C++にも持ち込みたいなと思い立ち、**Ordo**という"ビルドオーケストレーター"をRustで作っています。

```sh
ordo new myapp
cd myapp
ordo add vcpkg:raylib@6.0
ordo build
ordo run
```

これだけでraylibを使ったアプリがビルド・実行できます。`CMakeLists.txt` は書かずにすみます。

:::message
AIを用いて爆速開発しているため、実装に抜けが結構あると思います。(そこそこコードはレビュー・動作確認してますが…)
なのでIssue、フィードバック大歓迎です。
:::

GitHub:
<https://github.com/narusenia/ordo>

---

## CMakeLists.txtをもう書きたくない

### C/C++開発の手間

新しいC++プロジェクトを始めるとき、コードを書き始める前に必ずと言っていいほどやっていたことがありました。

1. `CMakeLists.txt`を書く（`cmake_minimum_required`から始まるアレ）
2. vcpkgかConanをセットアップする
3. ツールチェインファイルを設定する
4. `build/`ディレクトリを作って`cmake -B build -G Ninja`する
5. `compile_commands.json`をプロジェクトルートにシンボリックリンクする（clangdのために）
6. `.clang-format`と`.clang-tidy`を置く

Rustなら`cargo new myapp && cd myapp && cargo run`で終わる話です。C++では毎回この作業をやっていました。
後半は必要ないっちゃないですが、とにかく**CMakeLists.txtを書きたくない**んです。とにかく。

### CMakeの何が辛いか

CMakeは強力なツールです。それは認めます。ただ、新規の小〜中規模プロジェクトで使うには、いくつかの辛い点があります。

たとえば、「fmtライブラリを使って`Hello World!`する」だけのプロジェクトを考えてみてください(fmtはvcpkgからとってくることを想定しています)。

**CMakeの場合:**

```cmake
cmake_minimum_required(VERSION 3.20)
project(myapp LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(fmt CONFIG REQUIRED)

add_executable(myapp src/main.cpp)
target_link_libraries(myapp PRIVATE fmt::fmt)
```

これに加えて、vcpkgのツールチェインファイルを`-DCMAKE_TOOLCHAIN_FILE=...`で渡す必要があります。`find_package`が見つからなければ`CMAKE_PREFIX_PATH`を設定して...という作業が待っています。

**Ordoの場合:**

```toml
[package]
name = "myapp"
version = "0.1.0"
type = "executable"

[language]
cpp = "c++20"

[dependencies]
fmt = { version = "11.2.0", provider = "vcpkg" }
```

**とても見やすいと思いませんか？** ~~(toml贔屓)~~
ツールチェインの設定もvcpkgの呼び出しもOrdoが裏で処理します。しかも`new`コマンドひとつで基本の`Ordo.toml`は出力してくれます。

そもそもCMakeのDSLにずっと慣れませんでした。`target_link_libraries`のPUBLIC/PRIVATE/INTERFACEの使い分けとか、`find_package`のCONFIGモードとMODULEモードの違いとか、毎回調べ直していた気がします。プロジェクトが大きくなると`CMakeLists.txt`が増殖してどこで何を設定しているのか追えなくなるし、ぱっと見で構造を把握しづらい。なんで拡張子が`.txt`なのかも未だに腑に落ちていません。

CMakeは「ライブラリを何個か使ってビルドしたい」くらいの個人開発には、明らかにオーバースペックでした。

### 他のツールも試した

CMakeの辛さは自分だけが感じていたわけではなく、同じ問題意識から生まれたツールがすでにいくつか存在します。

**Meson**はCMakeより書きやすいDSLを持っていて、好きなところもありました。ただ、依存管理がWrapDB頼みで、vcpkgやConanと組み合わせようとすると自分で頑張る必要がありました。
<https://mesonbuild.com>

**xmake**はやりたいことが一番近いです。ビルドとパッケージ管理を統合していて、実際よくできています。
ただ、設定がLuaベースなので、TOMLの宣言的な記述が好きな自分にはしっくりきませんでした。
何より、Cargoの`new`, `add`, `build`, `run`という流れにとことん寄せたツールが欲しかったんです。
<https://xmake.io>

### Cargoを見て思ったこと

私はよく個人開発にRustを用いています。するとCargoの体験に体が慣れてしまいます。

```sh
cargo new myapp
cd myapp
cargo add serde --features derive
cargo build
cargo run
```

プロジェクト作成から依存追加、ビルド、実行まで、全部1つのツールで完結します。設定はTOMLに宣言的に書くだけ。ロックファイルで再現性も保証されます。この使い心地がC/C++にあってもいいはずです。

ないなら作ろう。そう思って開発を始めました。

---

## Ordoとは

**Ordo**（ラテン語で「秩序」）は、C/C++向けのビルド＆プロジェクト管理ツールです。もちろんRustで書いています。

狙いは1つ:

> **Don't replace the ecosystem. Orchestrate it.**

Ninja, vcpkg, Conan, pkg-configといった既存のツールはそのまま使います。ただし開発者が触るのは`Ordo.toml`と`ordo`コマンドだけ。裏側の配線はOrdoが引き受けます。

---

## 使い方 — raylibでウィンドウを開くまで

実際にOrdoを使って、raylibでウィンドウを表示するところまでやってみます。

### 1. プロジェクト作成

```sh
ordo new myapp
cd myapp
```

以下のファイルが生成されます:

```sh
myapp/
├── Ordo.toml
├── src/
│   └── main.cpp
└── .gitignore
```

`Ordo.toml`の中身はこうなっています:

```toml
[package]
name = "myapp"
version = "0.1.0"
type = "executable"

[language]
cpp = "c++20"
```

### 2. raylibを追加

```sh
ordo add vcpkg:raylib@6.0
```

`Ordo.toml`に自動的に追記されます:

```toml
[dependencies]
raylib = { version = "6.0", provider = "vcpkg" }
```

vcpkgのインストールやセットアップは`ordo`が裏で行います。初回はvcpkg自体のブートストラップも自動で走ります。

### 3. コードを書く

`src/main.cpp`を編集します:

```cpp
#include <raylib.h>

int main() {
    InitWindow(800, 600, "Hello Ordo");

    while (!WindowShouldClose()) {
        BeginDrawing();
        ClearBackground(RAYWHITE);
        DrawText("Hello from Ordo!", 200, 260, 40, DARKGRAY);
        EndDrawing();
    }

    CloseWindow();
    return 0;
}
```

### 4. ビルドして実行

```sh
ordo build
ordo run
```

これだけでraylibのウィンドウが開きます。`CMakeLists.txt`も`vcpkg.json`も`cmake -B build -G Ninja -DCMAKE_TOOLCHAIN_FILE=...`も書いていません。

<!-- TODO: ここにordo buildの出力やウィンドウのスクリーンショットを入れる -->

### 依存関係を確認する

何がインストールされたか確認したいときは`ordo tree`を使います:

```sh
ordo tree
```

```sh
myapp v0.1.0
├── raylib v6.0 (vcpkg)
│   libs: glfw3, nanosvg, nanosvgrast, raylib
│   frameworks: Cocoa, CoreFoundation, IOKit
│   include: /Users/.../vcpkg/installed/arm64-osx/include
```

raylibが依存しているglfw3やnanosvgも含めて、どのライブラリがリンクされているか一目でわかります。

### その他のコマンド

```sh
ordo build --release    # リリースビルド
ordo update             # 依存関係を再解決
ordo update raylib      # 特定の依存だけ更新
ordo clean              # ビルド成果物を削除
```

### ワークスペース

複数のプロジェクトをまとめて管理したい場合は、Cargoと同じようにワークスペースが使えます:

```toml
# ルートの Ordo.toml
[workspace]
members = ["apps/editor", "libs/core", "libs/render"]

[workspace.dependencies]
fmt = { version = "11.2.0", provider = "vcpkg" }
```

メンバー側では`{ workspace = true }`で共有依存を参照します。依存のバージョンはワークスペース全体で統一され、`Ordo.lock`も`target/`もルートに一元管理されます。

---

## 設計とアーキテクチャ

### 全体像

Ordoは3つのレイヤーで構成されています:

```sh
CLI Layer (clap)
  ↓
Core Engine
├── Manifest Parser     ← Ordo.toml のパース・バリデーション
├── Resolver            ← 依存関係の解決 (PubGrub)
├── Builder             ← build.ninja の直接生成
└── Module Scanner      ← C++ import/export の解析 (予定)
  ↓
Backend Layer
├── Providers           ← vcpkg, Conan, pkg-config, system, git
├── Compiler            ← Clang, GCC, MSVC の抽象化
├── Ninja Writer        ← .ninja ファイルの出力
└── Lua Runtime         ← git依存のビルドスクリプト実行
```

### なぜCMakeを生成しないのか

> 「Ordoの出力をCMakeLists.txtにすれば、CMakeのエコシステムがそのまま使えるのでは？」

これは最初に検討したアプローチですが、採用しませんでした。理由は3つほどあります。

#### 1. CMakeの制約をそのまま引き継いでしまう

Ordo → CMakeLists.txt → Ninja という構成にすると、間にCMakeを挟む分、CMakeの複雑さや暗黙の挙動をそのまま内部に抱え込むことになります。Ordoで解決したかった問題を、自分で再導入してしまう形です。

#### 2. Ninjaのフォーマットは十分シンプル

Ninjaの`build.ninja`は、ルール定義とビルドエッジの羅列でしかありません。コンパイラフラグ、インクルードパス、リンク設定を直接Ninja形式で書き出すほうが、CMakeのジェネレータ抽象を経由するよりシンプルで、ビルドエラーの原因も追いやすかったです。

将来的には`ordo generate cmake`のようなかたちで、CMakeプロジェクトとの連携もやりたいとは思っています。

#### 3. エラーのトレーサビリティ

ビルドエラーが起きたとき、「CMakeの問題かOrdoの問題か」を切り分けなくて済みます。Ordoが生成した`build.ninja`をNinjaが実行するだけなので、どこで何が起きたか分かりやすいです。

### なぜRustで書いたのか

シングルバイナリで配布できるのが大きいです。`clap`や`serde`、`tokio`あたりのクレートも揃っていて、CLIツールを書くには楽な環境でした。あとは、Cargoの使い心地を再現したいんだから、Cargoを一番よく知っている言語で書くのが自然だろう、と。

### 依存解決

依存関係の解決にはPubGrubアルゴリズムを使っています。セマンティックバージョニングの制約をSATソルバーで解決し、結果は`Ordo.lock`に記録して再現性を保証します。
ただ、全てがセマンティックバージョニングを採用しているわけではないので、それらはよしなに変換して解決しています。

### Git依存 + Luaビルドスクリプト

依存管理で一番悩んだのが「CMakeやMesonで管理されている外部ライブラリをどう扱うか」です。

vcpkgやConanにパッケージがあればそれを使えばいいのですが、すべてのライブラリがパッケージ化されているわけではありません。GitHubから直接クローンして使いたいケースは多いです。

そこで導入したのがLuaビルドスクリプトです。git依存に`with`フィールドでスクリプトを指定すると、クローン後にそのスクリプトが実行されます。

```toml
[dependencies]
sdl = { 
    git = "https://github.com/libsdl-org/SDL",
    tag = "release-3.4.8",
    with = "build.lua"
}
```

```lua
-- build.lua
exec("cmake", {
    "-B", "build",
    "-G", "Ninja",
    "-DCMAKE_BUILD_TYPE=" .. profile,
    "-DCMAKE_INSTALL_PREFIX=" .. out
})
exec("cmake", {"--build", "build"})
exec("cmake", {"--install", "build"})

return {
    include_dirs = { out .. "/include" },
    lib_dirs = { out .. "/lib" },
    libs = { "SDL3" }
}
```

ここで重要なのはセキュリティです。任意のスクリプトを実行できてしまうと、サプライチェーン攻撃のリスクがあります。そのため、Luaランタイムはサンドボックス化されています。

以下のような制約の上で実行されます。

- ファイルシステムへのアクセスは、クローン先ディレクトリと出力先ディレクトリに限定
- ネットワークアクセスは不可
- 使えるAPIは`exec`, `copy`, `mkdir`, `glob`のみ
- `with`フィールドで**明示的に**宣言しない限り、スクリプトは実行されない

ビルド結果（インクルードパス、ライブラリパスなど）は`Ordo.lock`にキャッシュされます。gitのコミットハッシュとスクリプトのハッシュが変わらない限り、再ビルドは走りません。

---

## 現状と今後

Ordoはまだ開発途中です。正直に現状を共有します。

### 今できること

基本的な開発ループは動いています:

- **プロジェクト作成**: `ordo new` でC/C++プロジェクトをスキャフォールド
- **ビルド・実行**: `ordo build`, `ordo run` でデバッグ/リリースビルド
- **依存管理**: vcpkg, Conan, pkg-config, system, gitの5つのプロバイダに対応。
- **Luaビルドスクリプト**: git依存のカスタムビルド対応
- **ワークスペース**: 基本的なモノレポ構成でのビルド
- **IDE連携**: `compile_commands.json`の自動生成
- **再現性**: `Ordo.lock`によるバージョン固定

「プロジェクトを作って、依存を入れて、ビルドして、実行する」このループは**ほぼ**実用レベル(過言)で動いています。

### 直近で取り組むこと

- `ordo test`: GoogleTest/Catch2/doctestの自動検出とテスト実行
- `ordo fmt` / `ordo lint`: clang-format/clang-tidy統合
- ビルドプロファイルの拡充（sanitizer、LTO、カスタムプロファイル）
- ワークスペースのフィーチャーフラグ対応
- 対応プロバイダの増強

### 将来構想

- **C++20モジュール対応**: BMI管理とモジュール依存スキャンの自動化。これはC++の未来にとって重要な機能で、どのビルドシステムもまだ完全にはサポートできていない領域です
- **クロスコンパイル**: `ordo build --target aarch64-linux-gnu`
- **Ordoレジストリ**: C/C++ライブラリの配布基盤。vcpkg/Conanに依存しないネイティブなパッケージエコシステム
- **ビルドキャッシュ**: sccache/ccache統合と、将来的にはリモートキャッシュ

---

## 類似ツールとの比較

同じ問題意識を持つツールは他にもあります。自分が使ってみた上での印象も含めて比較します。

|   | Ordo | CMake | xmake | Meson | Cargo (参考) |
|---|---|---|---|---|---|
| 設定形式 | TOML | 独自スクリプト | Lua | DSL | TOML |
| パッケージ管理 | 内蔵 (5プロバイダ) | 外部 (find_package) | 内蔵 (13+プロバイダ)| WrapDB | 内蔵 (crates.io) |
| ロックファイル | あり | なし | あり | なし | あり |
| ビルドバックエンド | Ninja直接生成 | Ninja/VS/Make | 自前 | Ninja | 自前 |
| ワークスペース | ネイティブ | add_subdirectory | あり | subproject | ネイティブ |

### xmakeについて

正直なところ、xmakeは現段階では**上位互換**だと思っています。ビルドとパッケージ管理の統合、モダンなCLI、ワークスペース対応。自分も使っていました。
それでもOrdoを作ったのは、TOML vs Luaの好みと、Cargoの操作感にとことん寄せたかったからです。~~あと、純粋な好奇心…~~

### CMakeについて

大規模で複雑なビルドが必要な場面では、今でもCMakeが現実的な選択肢だと思います。Ordoはそういう場面を狙っていません。

### Mesonについて

依存管理がWrapDB頼みなのが自分には合いませんでした。それ以外は嫌いじゃないです。

---

## まとめ

C/C++の開発、もっと楽にできるはずです。

Ordoはまだ全然完成していません。テスト、フォーマット、C++モジュール対応、やりたいことは山ほどあります。ただ、「プロジェクトを作って、依存を追加して、ビルドして、実行する」という基本ループは動いています。

興味があれば試してみてください:

:::message
もちろん安全性は確認していますが、実行はユーザーの自己責任です。
リンク先のスクリプトをよく読んでから実行してください。
:::

```sh
curl -fsSL https://raw.githubusercontent.com/narusenia/ordo/main/install.sh | sh
ordo new hello
cd hello
ordo build
ordo run
```

フィードバック・Issue・PRは大歓迎です。

- GitHub: <https://github.com/narusenia/ordo>
- License: MIT / Apache-2.0

<!-- TODO: スクリーンショットやGIFを追加（ordo build の出力、raylibウィンドウ） -->
