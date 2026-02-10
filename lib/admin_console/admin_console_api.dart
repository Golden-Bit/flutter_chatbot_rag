import 'package:boxed_ai/context_api_sdk.dart';
import 'package:boxed_ai/user_manager/auth_sdk/cognito_api_client.dart';

import 'admin_console_models.dart';

/// Wrapper per creare client coerenti con le impostazioni correnti.
/// Tutte le chiamate admin usano SOLO X-API-Key (adminToken).
class AdminConsoleApi {
  final AdminConsoleSettings settings;

  const AdminConsoleApi(this.settings);

  CognitoApiClient authClient() {
    return CognitoApiClient(
      baseUrl: settings.authBaseUrl.trim(),
      adminApiKey: settings.adminToken.trim(),
    );
  }

  ContextApiSdk contextSdk() {
    final sdk = ContextApiSdk();
    sdk.baseUrl = settings.ragBaseUrl.trim();
    sdk.whitelistAdminKey = settings.adminToken.trim(); // header X-API-Key
    return sdk;
  }
}
