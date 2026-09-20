# ICMP: DGRAM ソケットのサポート

- Status: Approved
- Issue: [eitoball/net-ping#21](https://github.com/eitoball/net-ping/issues/21)
- Date: 2026-09-20

## 背景

`Net::Ping::ICMP` は常に `Socket::SOCK_RAW` を使用しており、UNIX 系プラットフォームでは root 権限または `CAP_NET_RAW`（`cap2` gem 経由でチェック）が必須になっている。

macOS および Linux 2.6.39+ は、非特権ユーザーでも ICMP Echo を送受信できる `SOCK_DGRAM` + `IPPROTO_ICMP` ソケットをサポートしている（Apple 標準の `ping` コマンドも非 root 実行時にこれを使用する）。本設計は、これらのプラットフォームで DGRAM ソケットを利用し、root 権限なしで ICMP ping を可能にする。

## スコープ

- 対象: `Net::Ping::ICMP` クラス（`lib/net/ping/icmp.rb`）のソケット生成・パケット送受信ロジック
- IPv4 のみ（`AF_INET` / `IPPROTO_ICMP`）。ICMPv6 は対象外
- 対象外: Windows（現状の RAW 実装を維持）、動作未検証の Unix 系プラットフォーム（RAW のまま）

## プラットフォーム別方針

| プラットフォーム | ソケット選択 | 非特権対応 | 備考 |
| --- | --- | --- | --- |
| macOS | 常に `SOCK_DGRAM` | 可 | フォールバックなし。失敗時は例外をそのまま伝播 |
| Linux 2.6.39+ | `SOCK_DGRAM` → 失敗時 `SOCK_RAW` にフォールバック | 条件付き | GID が `net.ipv4.ping_group_range` に含まれる必要あり |
| Windows | 現状の `SOCK_RAW` のまま | 不可 | 変更しない |
| その他 Unix | 現状の `SOCK_RAW` のまま | 不可（デフォルト） | 未検証のため DGRAM を仮定しない |

### プラットフォーム判定

既存の Windows 判定（`File::ALT_SEPARATOR`）に加え、`RbConfig::CONFIG['host_os']` を用いて `darwin`（macOS）と `linux` を判定するヘルパーを追加する。上記 2 つに一致しない非 Windows 環境は「その他 Unix」として扱う。

## ソケット選択ロジック（`ping` メソッド内）

```
if Windows
  SOCK_RAW を使用（既存コードのまま、initialize 時の Win32::Security チェックも維持）

elsif macOS
  SOCK_DGRAM で Socket.new を試みる
  → 失敗した場合は例外をそのまま呼び出し元に伝播する（フォールバックしない）

elsif Linux
  SOCK_DGRAM で Socket.new を試みる
    成功 → DGRAM を使用
    Errno::EACCES / Errno::EPERM で失敗:
      root または CAP_NET_RAW を持つ → SOCK_RAW にフォールバックして使用
      持たない → StandardError を送出:
        "requires root privileges, setcap net_raw, or a
         net.ipv4.ping_group_range that includes this user's group"

else (その他 Unix)
  SOCK_RAW を使用（既存コードのまま）
end
```

## 特権チェックの再構成

現行実装は `initialize` 時に常に root/`cap2` チェックを行い、権限不足なら例外を送出している。この一律チェックは DGRAM 経路には不要なため、以下のように分岐させる。

- **Windows / その他 Unix**（RAW 専用プラットフォーム）: 現行通り `initialize` 時にチェックする。挙動は変更しない。
- **macOS**: `initialize` 時のチェックを行わない（DGRAM のみを使うため権限は不要）。
- **Linux**: `initialize` 時のチェックを行わない。DGRAM ソケット生成が権限エラーで失敗した場合にのみ、RAW フォールバック可否を判定するために root/`CAP_NET_RAW` チェックを実行する。

root/`CAP_NET_RAW` の判定ロジック自体（`cap2` gem があれば capability を見る、なければ `Process.euid == 0` のみで判定する）は既存コードをそのまま再利用する。

## パケット構築・解析

ICMP ペイロード（type/code/checksum/id/seq/data）の構築ロジック自体は RAW/DGRAM で共通のまま維持する。差分は以下の 2 点。

### ID 照合

- **RAW**: 従来通り、`initialize` 時に生成した `@ping_id`（`(Thread.current.object_id ^ Process.pid) & 0xffff`）を期待値として使う。
- **DGRAM**: カーネルが送信時に ICMP identifier をソケットのローカルポート相当の値で上書きする。送信後に `socket.local_address` から実際に割り当てられた値を取得し、それを Echo Reply 照合時の期待 ID として使う（`@ping_id` で生成した値は無視する）。

チェックサムは DGRAM の場合カーネルが計算・上書きするため、こちらで計算した値は送信データに含めても実質無視される。計算ロジック自体は RAW との共通コードパスを保つために変更しない。

### 受信解析

- **RAW**: 現状通り、受信データに IPv4 ヘッダが含まれる前提の固定オフセット（type: 20, echo reply の id/seq: 24, その他タイプの id/seq: 52）を使う。
- **DGRAM**: カーネルが IP ヘッダを取り除いた ICMP メッセージのみを返すため、オフセットを 20 バイト分前倒しする（type: 0, echo reply の id/seq: 4, その他タイプの id/seq: 32）。

使用中のソケット種別に応じて、どちらのオフセットセットを使うかを分岐する。

## エラーハンドリング

- Linux で DGRAM が権限エラーで失敗し、RAW へのフォールバック権限もない場合は、`net.ipv4.ping_group_range` への言及を含む `StandardError` を送出する（上記ロジック参照）。
- macOS で DGRAM ソケット生成が（権限以外の理由も含め）失敗した場合は、例外をそのまま伝播する。フォールバックは行わない。
- それ以外のソケット生成・送受信エラーハンドリングは既存の `ping` メソッドの挙動（タイムアウト処理、`@exception` への記録など）を変更しない。

## テスト方針

- 非 root 環境（CI 含む）で通る DGRAM 経路のテストを新設する。macOS では常時成功する前提で書く。Linux は `net.ipv4.ping_group_range` が許可されていない環境では該当テストを `omit` する。
- 既存の root 必須テスト（RAW 経路、Windows 昇格）はそのまま維持する。
- プラットフォーム判定・ソケット選択ロジック自体は、`RbConfig::CONFIG['host_os']` をスタブして各分岐（macOS/Linux/Windows/その他 Unix）を検証するユニットテストを追加する。
- パケットオフセット解析ロジック（RAW/DGRAM それぞれのオフセットでの id/seq/type 抽出）は、実ソケットを使わずに固定バイト列を渡すユニットテストで検証する。

## 非対象・今後の課題

- ICMPv6 対応
- Windows での非管理者対応（IP Helper API 相当の別実装が必要になるため別スコープ）
- macOS 以外の BSD 系・Solaris 等での DGRAM 対応検証
