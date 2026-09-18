import 'package:flutter/services.dart';

/// A app é vertical.
///
/// Os ecrãs são desenhados para uma coluna — o cartão, a caderneta de quotas, o
/// chat. Deitados ficavam com linhas larguíssimas e o cartão a ocupar o ecrã
/// todo. Trava-se aqui, e não no `AndroidManifest`/`Info.plist`, porque assim
/// um ecrã pode abrir a excepção: ver [permitirDeitar].
Future<void> fixarVertical() =>
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);

/// Para um ecrã que ganhe em ser visto deitado — um vídeo. Chamar ao entrar e
/// [fixarVertical] ao sair, senão a app fica a rodar a partir daí.
///
/// O `Info.plist` do iOS continua a declarar as orientações deitadas: sem isso,
/// nem esta chamada as conseguiria activar.
Future<void> permitirDeitar() => SystemChrome.setPreferredOrientations(const [
  DeviceOrientation.portraitUp,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
]);
