import { geoLocationManager } from '@kit.LocationKit';
import { AppLogger } from '../common/AppLogger';
import { ResolvedSceneLocation } from '../model/SceneContextModels';

const LOCATION_API_TIMEOUT_MS: number = 12000;
const LOCATION_REQUEST_TIMEOUT_MS: number = 10000;
const GEOCODE_TIMEOUT_MS: number = 6000;
const REVERSE_GEOCODE_TIMEOUT_MS: number = 3500;
const FRESH_LOCATION_MAX_AGE_MS: number = 2 * 60 * 1000;
const LAST_LOCATION_MAX_AGE_MS: number = 5 * 60 * 1000;
const LAST_LOCATION_MAX_ACCURACY_METERS: number = 200;

export class SceneContextLocationService {
  static async resolveAddress(address: string): Promise<ResolvedSceneLocation> {
    const description: string = address.trim();
    if (description.length === 0) {
      return ResolvedSceneLocation.fail('address');
    }
    try {
      if (!geoLocationManager.isGeocoderAvailable()) {
        return ResolvedSceneLocation.fail('geocoder_unavailable');
      }
      return await SceneContextLocationService.forwardGeocodeWithTimeout(description);
    } catch (error) {
      AppLogger.error('Unable to resolve scene address', error as Object);
      return ResolvedSceneLocation.fail('address_not_found');
    }
  }

  static async currentLocation(): Promise<ResolvedSceneLocation> {
    const result: ResolvedSceneLocation = await SceneContextLocationService.currentCoordinates(true);
    if (!result.success) {
      return result;
    }
    const fallback: string = `${result.latitude.toFixed(5)}, ${result.longitude.toFixed(5)}`;
    try {
      if (!geoLocationManager.isGeocoderAvailable()) {
        return ResolvedSceneLocation.ok(fallback, result.latitude, result.longitude);
      }
      return await SceneContextLocationService.reverseGeocodeWithTimeout(
        result.latitude, result.longitude, fallback);
    } catch (error) {
      AppLogger.error('Unable to reverse geocode current scene location', error as Object);
      return ResolvedSceneLocation.ok(fallback, result.latitude, result.longitude);
    }
  }

  static currentCoordinates(allowLastKnown: boolean = false): Promise<ResolvedSceneLocation> {
    try {
      if (!geoLocationManager.isLocationEnabled()) {
        return Promise.resolve(ResolvedSceneLocation.fail('location_disabled'));
      }
    } catch (error) {
      AppLogger.error('Unable to inspect the system location switch', error as Object);
      return Promise.resolve(ResolvedSceneLocation.fail('location_unavailable'));
    }
    const cached: ResolvedSceneLocation = SceneContextLocationService.lastKnownLocation(
      FRESH_LOCATION_MAX_AGE_MS);
    if (cached.success) {
      return Promise.resolve(cached);
    }
    return new Promise<ResolvedSceneLocation>((resolve: (value: ResolvedSceneLocation) => void) => {
      let finished: boolean = false;
      const timerId: number = setTimeout(() => {
        if (!finished) {
          finished = true;
          AppLogger.error('Timed out while obtaining current scene location');
          const fallback: ResolvedSceneLocation = allowLastKnown ?
            SceneContextLocationService.lastKnownLocation(LAST_LOCATION_MAX_AGE_MS) :
            ResolvedSceneLocation.fail('location_timeout');
          resolve(fallback.success ? fallback : ResolvedSceneLocation.fail('location_timeout'));
        }
      }, LOCATION_API_TIMEOUT_MS);
      geoLocationManager.getCurrentLocation({
        locatingPriority: geoLocationManager.LocatingPriority.PRIORITY_LOCATING_SPEED,
        locatingTimeoutMs: LOCATION_REQUEST_TIMEOUT_MS
      }).then((location: geoLocationManager.Location) => {
        if (finished) {
          return;
        }
        finished = true;
        clearTimeout(timerId);
        resolve(ResolvedSceneLocation.ok('', location.latitude, location.longitude));
      }).catch((error: Object) => {
        if (finished) {
          return;
        }
        finished = true;
        clearTimeout(timerId);
        AppLogger.error('Unable to obtain current scene location', error);
        const fallback: ResolvedSceneLocation = allowLastKnown ?
          SceneContextLocationService.lastKnownLocation(LAST_LOCATION_MAX_AGE_MS) :
          ResolvedSceneLocation.fail('location_unavailable');
        resolve(fallback.success ? fallback : ResolvedSceneLocation.fail('location_unavailable'));
      });
    });
  }

  private static lastKnownLocation(maxAgeMs: number): ResolvedSceneLocation {
    try {
      const location: geoLocationManager.Location = geoLocationManager.getLastLocation();
      const age: number = Math.max(0, Date.now() - location.timeStamp);
      if (age <= maxAgeMs && location.accuracy <= LAST_LOCATION_MAX_ACCURACY_METERS) {
        AppLogger.info('Using the cached last-known location for scene context');
        return ResolvedSceneLocation.ok('', location.latitude, location.longitude);
      }
    } catch (error) {
      AppLogger.error('Unable to use the last-known scene location', error as Object);
    }
    return ResolvedSceneLocation.fail('location_unavailable');
  }

  private static forwardGeocodeWithTimeout(description: string): Promise<ResolvedSceneLocation> {
    return new Promise<ResolvedSceneLocation>((resolve: (value: ResolvedSceneLocation) => void) => {
      let finished: boolean = false;
      const timerId: number = setTimeout(() => {
        if (!finished) {
          finished = true;
          AppLogger.error('Timed out while resolving a scene address');
          resolve(ResolvedSceneLocation.fail('geocode_timeout'));
        }
      }, GEOCODE_TIMEOUT_MS);
      geoLocationManager.getAddressesFromLocationName({
        description: description,
        locale: 'zh_CN',
        country: 'CN',
        maxItems: 1
      }).then((addresses: geoLocationManager.GeoAddress[]) => {
        if (finished) {
          return;
        }
        finished = true;
        clearTimeout(timerId);
        if (addresses.length === 0 || addresses[0].latitude === undefined ||
          addresses[0].longitude === undefined) {
          resolve(ResolvedSceneLocation.fail('address_not_found'));
          return;
        }
        const resolvedName: string =
          SceneContextLocationService.addressText(addresses[0], description);
        resolve(ResolvedSceneLocation.ok(resolvedName,
          addresses[0].latitude as number, addresses[0].longitude as number));
      }).catch((error: Object) => {
        if (finished) {
          return;
        }
        finished = true;
        clearTimeout(timerId);
        AppLogger.error('Unable to resolve scene address', error);
        resolve(ResolvedSceneLocation.fail('address_not_found'));
      });
    });
  }

  private static reverseGeocodeWithTimeout(latitude: number, longitude: number,
    fallback: string): Promise<ResolvedSceneLocation> {
    return new Promise<ResolvedSceneLocation>((resolve: (value: ResolvedSceneLocation) => void) => {
      let finished: boolean = false;
      const timerId: number = setTimeout(() => {
        if (!finished) {
          finished = true;
          resolve(ResolvedSceneLocation.ok(fallback, latitude, longitude));
        }
      }, REVERSE_GEOCODE_TIMEOUT_MS);
      geoLocationManager.getAddressesFromLocation({
        latitude: latitude,
        longitude: longitude,
        locale: 'zh_CN',
        country: 'CN',
        maxItems: 1
      }).then((addresses: geoLocationManager.GeoAddress[]) => {
        if (finished) {
          return;
        }
        finished = true;
        clearTimeout(timerId);
        const addressName: string = addresses.length > 0 ?
          SceneContextLocationService.addressText(addresses[0], fallback) : fallback;
        resolve(ResolvedSceneLocation.ok(addressName, latitude, longitude));
      }).catch((error: Object) => {
        if (finished) {
          return;
        }
        finished = true;
        clearTimeout(timerId);
        AppLogger.error('Unable to reverse geocode current scene location', error);
        resolve(ResolvedSceneLocation.ok(fallback, latitude, longitude));
      });
    });
  }

  private static addressText(address: geoLocationManager.GeoAddress, fallback: string): string {
    const parts: string[] = new Array<string>();
    SceneContextLocationService.appendPart(parts, address.administrativeArea);
    SceneContextLocationService.appendPart(parts, address.subAdministrativeArea);
    SceneContextLocationService.appendPart(parts, address.locality);
    SceneContextLocationService.appendPart(parts, address.subLocality);
    SceneContextLocationService.appendPart(parts, address.placeName);
    return parts.length > 0 ? parts.join('') : fallback;
  }

  private static appendPart(parts: string[], value: string | undefined): void {
    if (value !== undefined && value.trim().length > 0 &&
      (parts.length === 0 || parts[parts.length - 1] !== value.trim())) {
      parts.push(value.trim());
    }
  }
}
