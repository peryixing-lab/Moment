import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import agconnectAuth, { AuthUser, TokenResult } from '@hw-agconnect/auth';
import { AppLogger } from '../common/AppLogger';

const STORE_NAME: string = 'moment_huawei_account';
const KEY_UID: string = 'accountUid';
const KEY_EMAIL: string = 'accountEmail';
const KEY_DISPLAY_NAME: string = 'accountDisplayName';
const KEY_PHOTO_URL: string = 'accountPhotoUrl';
const KEY_SIGNED_IN_AT: string = 'accountSignedInAt';
const AGC_CONFIG_FILE: string = 'agconnect-services.json';
const TOKEN_REFRESH_INTERVAL_MS: number = 45 * 60 * 1000;

export class HuaweiAccount {
  uid: string = '';
  email: string = '';
  displayName: string = '';
  photoUrl: string = '';
  signedInAt: number = 0;
}

export class AccountService {
  private static initialized: boolean = false;
  private static lastTokenRefreshAt: number = 0;

  static initialize(context: common.Context): boolean {
    return AccountService.ensureInitialized(context);
  }

  static async refreshSession(context: common.Context, forceRefresh: boolean = false): Promise<boolean> {
    if (!AccountService.ensureInitialized(context)) {
      return false;
    }
    try {
      const user: AuthUser | null = await agconnectAuth.getCurrentUser();
      if (user === null) {
        AppLogger.error('No HUAWEI account session is available for cloud sync');
        return false;
      }
      const now: number = Date.now();
      const shouldRefresh: boolean = forceRefresh || AccountService.lastTokenRefreshAt <= 0 ||
        now - AccountService.lastTokenRefreshAt >= TOKEN_REFRESH_INTERVAL_MS;
      let didRefresh: boolean = shouldRefresh;
      let token: TokenResult;
      try {
        token = await user.getToken(shouldRefresh);
      } catch (error) {
        if (shouldRefresh) {
          const businessError: BusinessError = error as BusinessError;
          const message: string = typeof businessError.message === 'string' ?
            businessError.message : 'user token refresh failed';
          throw new Error(message);
        }
        AppLogger.info('Cached HUAWEI user token was unavailable, forcing a refresh');
        token = await user.getToken(true);
        didRefresh = true;
      }
      const tokenValue: string = token.getString();
      if (tokenValue.length === 0) {
        AppLogger.error('The refreshed HUAWEI user token is empty');
        return false;
      }
      if (didRefresh) {
        AccountService.lastTokenRefreshAt = now;
      }
      AppLogger.info(`HUAWEI user session is ready for cloud sync, token length: ${tokenValue.length}`);
      return true;
    } catch (error) {
      AppLogger.error('Unable to refresh the HUAWEI user session', error as Object);
      return false;
    }
  }

  static async login(context: common.Context): Promise<string> {
    try {
      if (!AccountService.ensureInitialized(context)) {
        return 'AGC 配置文件缺失或格式不正确，请从 AGC 控制台重新下载。';
      }
      const first: string = await AccountService.attemptSignIn(context);
      if (first.length === 0) {
        return '';
      }
      AppLogger.info('Sign-in attempt failed, clearing session and retrying');
      await AccountService.disableAnySession();
      return await AccountService.attemptSignIn(context);
    } catch (error) {
      AppLogger.error('Unable to sign in with the HUAWEI ID', error as Object);
      return AccountService.loginErrorDetail(error as Object);
    }
  }

  private static async attemptSignIn(context: common.Context): Promise<string> {
    try {
      const result = await agconnectAuth.signIn({
        credentialInfo: { kind: 'hwid' },
        autoCreateUser: true
      });
      const user = result.getUser();
      if (!AccountService.store(context, user.getUid(), user.getEmail(),
        user.getDisplayName(), user.getPhotoUrl(), Date.now())) {
        AppLogger.error('Unable to store the signed-in account locally');
        return '登录成功但本地存储失败，请重试。';
      }
      AccountService.lastTokenRefreshAt = Date.now();
      AppLogger.info(`HUAWEI ID sign-in succeeded: ${user.getUid()}`);
      return '';
    } catch (error) {
      AppLogger.error('HUAWEI ID sign-in attempt failed', error as Object);
      return AccountService.loginErrorDetail(error as Object);
    }
  }

  private static disableAnySession(): Promise<void> {
    return new Promise<void>((resolve: (value: void) => void) => {
      try {
        agconnectAuth.getCurrentUser().then((user) => {
          if (user === null) {
            resolve();
            return;
          }
          agconnectAuth.signOut().then(() => {
            resolve();
          }).catch((error: Object) => {
            AppLogger.error('Unable to sign out an existing AGC session', error);
            resolve();
          });
        }).catch((error: Object) => {
          AppLogger.error('Unable to query an existing AGC session', error);
          resolve();
        });
      } catch (error) {
        AppLogger.error('Unable to clear an existing AGC session', error as Object);
        resolve();
      }
    });
  }

  private static loginErrorDetail(error: Object): string {
    const businessError: BusinessError = error as BusinessError;
    const code: number = businessError.code;
    const message: string = typeof businessError.message === 'string' ?
      businessError.message : '';
    let hint: string = '';
    switch (code) {
      case 1001502002:
        hint = '应用未授权，请检查 AGC 应用关联与签名证书指纹。';
        break;
      case 1001500003:
        hint = '所需权限或范围不支持，请在 AGC 认证服务中开启华为账号登录。';
        break;
      case 1001500005:
        hint = '功能受限，请在 AGC 认证服务中开启该登录方式。';
        break;
      case 14000816:
        hint = '客户端密钥错误，请下载包含密钥的配置文件。';
        break;
      case 204:
        hint = '网络不可用，请检查后重试。';
        break;
      case 1210005:
        hint = '仍有已登录会话，正在尝试自动清理后重试；若持续失败请在设置中退出华为账号后再试。';
        break;
      default:
        break;
    }
    if (hint.length === 0 && message.includes('client token auth failed')) {
      hint = '客户端凭据校验失败，请在 AGC 认证服务项目设置核对客户端 ID/密钥，并重新下载 agconnect-services.json。';
    }
    if (typeof code === 'number' && code > 0) {
      return hint.length > 0 ? `登录失败(${code})：${hint}` :
        `登录失败(${code})${message.length > 0 ? `：${message}` : ''}`;
    }
    return message.length > 0 ? `登录失败：${message}` : '登录失败，请稍后重试。';
  }

  static logout(context: common.Context): Promise<boolean> {
    return new Promise<boolean>((resolve: (value: boolean) => void) => {
      try {
        agconnectAuth.signOut().then(() => {
          AccountService.clear(context);
          AccountService.lastTokenRefreshAt = 0;
          AppLogger.info('HUAWEI account signed out');
          resolve(true);
        }).catch((error: Object) => {
          AppLogger.error('Unable to sign out of the HUAWEI account', error);
          AccountService.clear(context);
          AccountService.lastTokenRefreshAt = 0;
          resolve(true);
        });
      } catch (error) {
        AppLogger.error('Unable to sign out of the HUAWEI account', error as Object);
        AccountService.clear(context);
        AccountService.lastTokenRefreshAt = 0;
        resolve(true);
      }
    });
  }

  static load(context: common.Context): HuaweiAccount | undefined {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, {
        name: STORE_NAME,
        storageType: preferences.StorageType.XML
      });
      const uidValue: preferences.ValueType = store.getSync(KEY_UID, '');
      if (typeof uidValue !== 'string' || uidValue.length === 0) {
        return undefined;
      }
      const emailValue: preferences.ValueType = store.getSync(KEY_EMAIL, '');
      const displayNameValue: preferences.ValueType = store.getSync(KEY_DISPLAY_NAME, '');
      const photoUrlValue: preferences.ValueType = store.getSync(KEY_PHOTO_URL, '');
      const signedInAtValue: preferences.ValueType = store.getSync(KEY_SIGNED_IN_AT, 0);
      const account: HuaweiAccount = new HuaweiAccount();
      account.uid = uidValue;
      account.email = typeof emailValue === 'string' ? emailValue : '';
      account.displayName = typeof displayNameValue === 'string' ? displayNameValue : '';
      account.photoUrl = typeof photoUrlValue === 'string' ? photoUrlValue : '';
      account.signedInAt = typeof signedInAtValue === 'number' ? signedInAtValue : 0;
      return account;
    } catch (error) {
      AppLogger.error('Unable to load the HUAWEI account', error as Object);
      return undefined;
    }
  }

  static isSignedIn(context: common.Context): boolean {
    return AccountService.load(context) !== undefined;
  }

  private static ensureInitialized(context: common.Context): boolean {
    if (AccountService.initialized) {
      return true;
    }
    try {
      const config: Uint8Array = context.resourceManager.getRawFileContentSync(
        AGC_CONFIG_FILE);
      const text: string = util.TextDecoder.create('utf-8').decodeToString(config);
      if (!text.includes('"client"')) {
        AppLogger.error('AGC config is missing, download agconnect-services.json from AGC');
        return false;
      }
      const parsed: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
      const client: Record<string, Object> =
        parsed['client'] as Record<string, Object> | undefined ?? {};
      const clientId: string = typeof client['client_id'] === 'string' ?
        client['client_id'] : '';
      const clientSecret: string = typeof client['client_secret'] === 'string' ?
        client['client_secret'] : '';
      agconnectAuth.init(context, text);
      if (clientId.length === 0) {
        AppLogger.error('AGC config is missing the client id');
        return false;
      }
      if (clientSecret.length === 0) {
        AppLogger.error('AGC config is missing the client secret, ' +
          'download the config with keys included');
        return false;
      }
      AccountService.initialized = true;
      return true;
    } catch (error) {
      AppLogger.error('Unable to initialize the AGC authentication service', error as Object);
      return false;
    }
  }

  private static store(context: common.Context, uid: string, email: string,
    displayName: string, photoUrl: string, signedInAt: number): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, {
        name: STORE_NAME,
        storageType: preferences.StorageType.XML
      });
      store.putSync(KEY_UID, uid);
      store.putSync(KEY_EMAIL, email);
      store.putSync(KEY_DISPLAY_NAME, displayName);
      store.putSync(KEY_PHOTO_URL, photoUrl);
      store.putSync(KEY_SIGNED_IN_AT, signedInAt);
      store.flushSync();
      return true;
    } catch (error) {
      AppLogger.error('Unable to store the HUAWEI account', error as Object);
      return false;
    }
  }

  private static clear(context: common.Context): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, {
        name: STORE_NAME,
        storageType: preferences.StorageType.XML
      });
      store.putSync(KEY_UID, '');
      store.putSync(KEY_EMAIL, '');
      store.putSync(KEY_DISPLAY_NAME, '');
      store.putSync(KEY_PHOTO_URL, '');
      store.putSync(KEY_SIGNED_IN_AT, 0);
      store.flushSync();
      return true;
    } catch (error) {
      AppLogger.error('Unable to clear the HUAWEI account', error as Object);
      return false;
    }
  }
}
