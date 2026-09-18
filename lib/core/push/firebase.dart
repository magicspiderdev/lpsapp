import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Projecto Firebase do clube: `mylps-3fbdb`, o mesmo da app antiga.
///
/// Serve tal qual porque o `applicationId` não mudou (`pt.magicspider.mslps`).
/// O emissor do clube continua a ler a tabela `user_tokens` onde o
/// `POST /dispositivos` escreve — ver §4.15 do guia.
///
/// Estes valores não são segredos: viajam dentro de qualquer APK publicado. O
/// que os protege é a restrição da chave na consola do Google Cloud (pacote
/// Android + impressão digital do certificado), não o facto de estarem aqui.
///
/// Opções explícitas em vez de `google-services.json` e do plugin de Gradle: o
/// build de debug usa `pt.magicspider.mslps.dev` e o plugin recusa-se a compilar
/// quando não encontra um cliente com esse nome de pacote no ficheiro.
const _android = FirebaseOptions(
  apiKey: 'AIzaSyDh17TqtOCirjJQ84hXToV3cQMgt60l6eQ',
  appId: '1:333604454420:android:1daa66dc79d06cc4006701',
  messagingSenderId: '333604454420',
  projectId: 'mylps-3fbdb',
  storageBucket: 'mylps-3fbdb.firebasestorage.app',
);

/// `null` = esta plataforma ainda não tem app registada no projecto.
///
/// O iOS nunca existiu na app antiga: falta criar a app no Firebase, o
/// `GoogleService-Info.plist` e a chave APNs no Apple Developer. Até lá, a app
/// corre em iOS sem push, em vez de rebentar no arranque.
FirebaseOptions? get opcoesFirebase =>
    defaultTargetPlatform == TargetPlatform.android ? _android : null;
