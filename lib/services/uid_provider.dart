/// Fuente del uid de la bodega actual. En producción lo implementa
/// [AuthService] (ver `auth_service.dart`); los repositorios lo reciben
/// inyectado en vez de resolver `AuthService.instance` directamente, para
/// poder testear el estampado de `bodega_id` con un uid real sin depender
/// de Firebase.
abstract class UidProvider {
  /// uid de la sesión activa, o `null` si no hay sesión (o si Firebase no
  /// está disponible todavía). Nunca lanza.
  String? get currentUid;
}
