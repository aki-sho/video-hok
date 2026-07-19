Video HOK Portable {{VERSION}}
==============================

起動方法
--------
「{{PORTABLE_EXE}}」をダブルクリックしてください。
インストールは不要です。

PortableDataの場所
------------------
初回起動時、EXEと同じフォルダに次のフォルダが作成されます。

{{PORTABLE_DATA}}

設定、アプリデータ、ログ、キャッシュ、一時ファイル、WebViewデータは
すべてこのPortableDataフォルダ内へ保存されます。

移動方法
--------
別のフォルダやUSBメモリへ移動する場合は、次の2つを一緒に移動してください。

1. {{PORTABLE_EXE}}
2. {{PORTABLE_DATA}}

EXEだけを移動して起動すると、移動先に新しいPortableDataが作成されます。

削除方法
--------
アプリを終了してから、EXEと「{{PORTABLE_DATA}}」フォルダを削除してください。
アンインストーラーはありません。ファイル関連付けや常駐設定は作成しません。

WebView2 Runtimeについて
------------------------
このポータブル版はMicrosoft Edge WebView2 Runtimeを同梱していません。
起動できない場合は、Microsoft Edge WebView2 Runtime Evergreen版が
Windowsにインストールされていることを確認してください。

Video HOK
https://github.com/aki-sho/video-hok
