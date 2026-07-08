import CoreLocation

/// CoreLocation 을 감싸 "현재 위치(위/경도)"를 한 번씩 가져오는 래퍼.
///
/// 상시 추적이 아니라 요청 시 1회만 측위(requestLocation)해서 배터리를 아낍니다.
/// 권한이 없으면 요청하고, 거부 상태면 오류를 돌려줍니다.
@MainActor
final class LocationManager: NSObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()

    /// 진행 중인 위치 요청의 continuation(중복 요청 방지를 위해 하나만).
    private var pending: CheckedContinuation<CLLocationCoordinate2D, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer // 날씨엔 km 정확도면 충분.
    }

    /// 현재 권한 상태.
    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    /// 현재 위치를 1회 측위해 좌표를 반환. 권한이 없으면 먼저 요청합니다.
    func requestCurrentCoordinate() async throws -> CLLocationCoordinate2D {
        switch manager.authorizationStatus {
        case .authorized, .authorizedAlways:
            break
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            // 권한 콜백을 기다렸다가 측위하도록, 콜백에서 이어서 처리.
        case .denied, .restricted:
            throw LocationError.denied
        @unknown default:
            throw LocationError.denied
        }

        return try await withCheckedThrowingContinuation { cont in
            // 동시에 하나의 요청만 허용(이전 것이 있으면 취소 처리).
            if let existing = pending {
                existing.resume(throwing: LocationError.superseded)
            }
            pending = cont
            manager.requestLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate
    //
    // 델리게이트 요구사항은 nonisolated 라, 콜백을 받은 뒤 MainActor 로 넘겨
    // 상태(pending 등)를 안전하게 다룹니다.

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coord = locations.last?.coordinate
        Task { @MainActor in
            if let coord {
                self.finish(.success(coord))
            } else {
                self.finish(.failure(LocationError.noFix))
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(.failure(error)) }
    }

    /// 권한이 바뀌면(예: 팝업에서 허용) 대기 중인 요청이 있으면 측위를 재시도.
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorized, .authorizedAlways:
                if self.pending != nil { self.manager.requestLocation() }
            case .denied, .restricted:
                self.finish(.failure(LocationError.denied))
            default:
                break
            }
        }
    }

    private func finish(_ result: Result<CLLocationCoordinate2D, Error>) {
        guard let cont = pending else { return }
        pending = nil
        cont.resume(with: result)
    }
}

enum LocationError: LocalizedError {
    case denied
    case noFix
    case superseded

    var errorDescription: String? {
        switch self {
        case .denied:     return "위치 권한이 거부되었습니다. 시스템 설정에서 허용하세요."
        case .noFix:      return "현재 위치를 확인하지 못했습니다."
        case .superseded: return "새 위치 요청으로 대체되었습니다."
        }
    }
}
