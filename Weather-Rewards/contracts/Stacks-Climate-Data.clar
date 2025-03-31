;; Weather Data Oracle Contract
;; Handles IoT device registration, data submission, and reward distribution

;; Administrative Constants
(define-constant contract-administrator tx-sender)
(define-constant required-minimum-stake u100000000) ;; 100 STX minimum stake
(define-constant data-submission-reward u1000000) ;; 1 STX per valid submission
(define-constant allowed-consensus-deviation 10) ;; 10% maximum deviation for consensus
(define-constant required-validator-count u3) ;; Minimum validators for consensus

;; Quality Thresholds
(define-constant minimum-accuracy-threshold u80) ;; Minimum accuracy score
(define-constant device-penalty-amount u10000000) ;; 10 STX penalty
(define-constant device-inactivity-limit u1440) ;; Max blocks without submission
(define-constant proposal-approval-threshold u75) ;; 75% for proposal passing

;; Error Constants
(define-constant ERR-UNAUTHORIZED-ACCESS (err u401))
(define-constant ERR-DEVICE-ALREADY-EXISTS (err u402))
(define-constant ERR-INSUFFICIENT-STAKE-AMOUNT (err u403))
(define-constant ERR-DEVICE-NOT-REGISTERED (err u404))
(define-constant ERR-INVALID-SUBMISSION-DATA (err u405))
(define-constant ERR-CONSENSUS-VALIDATION-FAILED (err u406))
(define-constant ERR-ACCURACY-BELOW-THRESHOLD (err u407))
(define-constant ERR-DEVICE-INACTIVE (err u408))
(define-constant ERR-STAKE-REQUIREMENT-NOT-MET (err u409))
(define-constant ERR-INVALID-GOVERNANCE-PROPOSAL (err u410))

;; Data Variables
(define-data-var device-id-counter uint u0)
(define-data-var governance-proposal-counter uint u0)

;; Data Structures

;; Device Registration and Management
(define-map device-id-registry uint (string-ascii 24))
(define-map device-ownership-registry principal (string-ascii 24))

;; Core Device Information
(define-map registered-devices
    { device-id: (string-ascii 24) }
    {
        device-owner: principal,
        staked-amount: uint,
        device-accuracy: uint,
        submission-count: uint,
        device-location: {
            device-latitude: int,
            device-longitude: int
        }
    }
)

;; Device Performance Metrics
(define-map device-performance-metrics
    { device-id: (string-ascii 24) }
    {
        last-active-block: uint,
        successful-validations: uint,
        total-earned-rewards: uint,
        total-incurred-penalties: uint
    }
)

;; Collected Weather Data
(define-map collected-weather-data
    { 
        device-id: (string-ascii 24),
        collection-timestamp: uint 
    }
    {
        recorded-temperature: int,
        recorded-humidity: uint,
        recorded-pressure: uint,
        recorded-wind-speed: uint,
        data-validation-status: bool
    }
)

;; Regional Consensus Data
(define-map regional-consensus-data
    { 
        region-hash: (string-ascii 16),
        consensus-timestamp: uint 
    }
    {
        regional-temperature-avg: int,
        regional-humidity-avg: uint,
        regional-pressure-avg: uint,
        regional-wind-speed-avg: uint,
        contributing-devices: uint
    }
)

;; Governance System
(define-map governance-proposals
    { proposal-id: uint }
    {
        proposal-creator: principal,
        proposal-title: (string-ascii 50),
        proposal-description: (string-ascii 500),
        target-parameter: (string-ascii 20),
        proposed-value: uint,
        supporting-votes: uint,
        opposing-votes: uint,
        proposal-status: (string-ascii 10),
        voting-deadline: uint
    }
)

(define-map voter-participation
    { proposal-id: uint, voter-address: principal }
    { vote-decision: bool }
)

;; Register a new weather data collection device
(define-public (register-new-device 
                (device-id (string-ascii 24)) 
                (device-latitude int)
                (device-longitude int))
    (let ((existing-device-check (map-get? registered-devices {device-id: device-id})))
        (if (is-some existing-device-check)
            ERR-DEVICE-ALREADY-EXISTS
            (begin
                (map-set registered-devices
                    {device-id: device-id}
                    {
                        device-owner: tx-sender,
                        staked-amount: u0,
                        device-accuracy: u100,
                        submission-count: u0,
                        device-location: {
                            device-latitude: device-latitude,
                            device-longitude: device-longitude
                        }
                    })
                (map-set device-performance-metrics
                    {device-id: device-id}
                    {
                        last-active-block: block-height,
                        successful-validations: u0,
                        total-earned-rewards: u0,
                        total-incurred-penalties: u0
                    })
                (map-set device-ownership-registry tx-sender device-id)
                (ok true)))))

;; Stake tokens to increase device reputation and eligibility
(define-public (add-stake-to-device (device-id (string-ascii 24)) (stake-amount uint))
    (let ((device-data (unwrap! (map-get? registered-devices {device-id: device-id})
                         ERR-DEVICE-NOT-REGISTERED)))
        (if (and
            (is-eq tx-sender (get device-owner device-data))
            (>= stake-amount required-minimum-stake))
            (begin
                (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
                (map-set registered-devices
                    {device-id: device-id}
                    (merge device-data {staked-amount: (+ (get staked-amount device-data) stake-amount)}))
                (ok true))
            ERR-INSUFFICIENT-STAKE-AMOUNT)))

;; Data Submission Functions

;; Submit weather data collected by a device
(define-public (submit-weather-data 
               (device-id (string-ascii 24))
               (collection-timestamp uint)
               (recorded-temperature int)
               (recorded-humidity uint)
               (recorded-pressure uint)
               (recorded-wind-speed uint))
    (let ((device-data (unwrap! (map-get? registered-devices {device-id: device-id})
                          ERR-DEVICE-NOT-REGISTERED))
          (device-metrics (default-to 
                          {
                              last-active-block: u0,
                              successful-validations: u0,
                              total-earned-rewards: u0,
                              total-incurred-penalties: u0
                          }
                          (map-get? device-performance-metrics {device-id: device-id}))))
        (if (is-eq tx-sender (get device-owner device-data))
            (begin
                (map-set collected-weather-data
                    {
                        device-id: device-id,
                        collection-timestamp: collection-timestamp
                    }
                    {
                        recorded-temperature: recorded-temperature,
                        recorded-humidity: recorded-humidity,
                        recorded-pressure: recorded-pressure,
                        recorded-wind-speed: recorded-wind-speed,
                        data-validation-status: false
                    })
                (map-set device-performance-metrics
                    {device-id: device-id}
                    (merge device-metrics {last-active-block: block-height}))
                (map-set registered-devices
                    {device-id: device-id}
                    (merge device-data 
                        {submission-count: (+ (get submission-count device-data) u1)}))
                (ok true))
            ERR-UNAUTHORIZED-ACCESS)))

;; Data Validation Functions

;; Validate submitted data against regional consensus
(define-public (validate-submitted-data 
               (device-id (string-ascii 24))
               (collection-timestamp uint)
               (region-hash (string-ascii 16)))
    (let ((submission-data (unwrap! (map-get? collected-weather-data 
                              {device-id: device-id, collection-timestamp: collection-timestamp})
                           ERR-DEVICE-NOT-REGISTERED))
          (consensus-check (map-get? regional-consensus-data 
                          {region-hash: region-hash, consensus-timestamp: collection-timestamp}))
          (device-data (unwrap! (map-get? registered-devices {device-id: device-id})
                          ERR-DEVICE-NOT-REGISTERED))
          (device-metrics (unwrap! (map-get? device-performance-metrics {device-id: device-id})
                                 ERR-DEVICE-NOT-REGISTERED)))
        (if (is-some consensus-check)
            (let ((regional-data (unwrap-panic consensus-check)))
                (if (and
                    (check-measurement-validity 
                        (get recorded-temperature submission-data)
                        (get regional-temperature-avg regional-data))
                    (check-measurement-validity 
                        (to-int (get recorded-humidity submission-data))
                        (to-int (get regional-humidity-avg regional-data)))
                    (check-measurement-validity 
                        (to-int (get recorded-pressure submission-data))
                        (to-int (get regional-pressure-avg regional-data)))
                    (check-measurement-validity 
                        (to-int (get recorded-wind-speed submission-data))
                        (to-int (get regional-wind-speed-avg regional-data))))
                    (begin
                        (try! (as-contract 
                            (stx-transfer? data-submission-reward contract-administrator 
                                         (get device-owner device-data))))
                        (map-set collected-weather-data
                            {device-id: device-id, collection-timestamp: collection-timestamp}
                            (merge submission-data {data-validation-status: true}))
                        (map-set device-performance-metrics
                            {device-id: device-id}
                            (merge device-metrics 
                                {
                                    successful-validations: (+ (get successful-validations device-metrics) u1),
                                    total-earned-rewards: (+ (get total-earned-rewards device-metrics) data-submission-reward)
                                }))
                        (ok true))
                    ERR-CONSENSUS-VALIDATION-FAILED))
            ERR-INVALID-SUBMISSION-DATA)))

;; Quality Control Functions

;; Report a malfunctioning device
(define-public (report-device-malfunction (device-id (string-ascii 24)))
    (let ((device-data (unwrap! (map-get? registered-devices {device-id: device-id})
                          ERR-DEVICE-NOT-REGISTERED))
          (device-metrics (unwrap! (map-get? device-performance-metrics {device-id: device-id})
                                 ERR-DEVICE-NOT-REGISTERED)))
        (if (< (get device-accuracy device-data) minimum-accuracy-threshold)
            (begin
                (try! (as-contract 
                    (stx-transfer? device-penalty-amount 
                                 (get device-owner device-data)
                                 contract-administrator)))
                (map-set device-performance-metrics
                    {device-id: device-id}
                    (merge device-metrics 
                        {total-incurred-penalties: (+ (get total-incurred-penalties device-metrics) u1)}))
                (ok true))
            ERR-INVALID-SUBMISSION-DATA)))

;; Update device status based on activity
(define-public (update-device-activity-status (device-id (string-ascii 24)))
    (let ((device-data (unwrap! (map-get? registered-devices {device-id: device-id})
                          ERR-DEVICE-NOT-REGISTERED))
          (device-metrics (unwrap! (map-get? device-performance-metrics {device-id: device-id})
                                 ERR-DEVICE-NOT-REGISTERED)))
        (if (> (- block-height (get last-active-block device-metrics)) 
               device-inactivity-limit)
            (begin
                (map-set registered-devices
                    {device-id: device-id}
                    (merge device-data {device-accuracy: u0}))
                (ok true))
            ERR-INVALID-SUBMISSION-DATA)))

;; Governance Functions

;; Create a new governance proposal
(define-public (create-governance-proposal 
    (proposal-title (string-ascii 50))
    (proposal-description (string-ascii 500))
    (target-parameter (string-ascii 20))
    (proposed-value uint))
    (let ((new-proposal-id (+ (var-get governance-proposal-counter) u1))
          (device-id (unwrap! (map-get? device-ownership-registry tx-sender)
                             ERR-UNAUTHORIZED-ACCESS))
          (device-data (unwrap! (map-get? registered-devices {device-id: device-id})
                          ERR-UNAUTHORIZED-ACCESS)))
        (if (>= (get staked-amount device-data) (* required-minimum-stake u2))
            (begin
                (map-set governance-proposals
                    {proposal-id: new-proposal-id}
                    {
                        proposal-creator: tx-sender,
                        proposal-title: proposal-title,
                        proposal-description: proposal-description,
                        target-parameter: target-parameter,
                        proposed-value: proposed-value,
                        supporting-votes: u0,
                        opposing-votes: u0,
                        proposal-status: "active",
                        voting-deadline: (+ block-height u1440)
                    })
                (var-set governance-proposal-counter new-proposal-id)
                (ok new-proposal-id))
            ERR-STAKE-REQUIREMENT-NOT-MET)))

;; Cast vote on an active governance proposal
(define-public (vote-on-governance-proposal (proposal-id uint) (support-proposal bool))
    (let ((proposal-data (unwrap! (map-get? governance-proposals {proposal-id: proposal-id})
                            ERR-INVALID-GOVERNANCE-PROPOSAL))
          (device-id (unwrap! (map-get? device-ownership-registry tx-sender)
                             ERR-UNAUTHORIZED-ACCESS))
          (device-data (unwrap! (map-get? registered-devices {device-id: device-id})
                          ERR-UNAUTHORIZED-ACCESS)))
        (if (and
            (is-eq (get proposal-status proposal-data) "active")
            (< block-height (get voting-deadline proposal-data))
            (is-none (map-get? voter-participation 
                              {proposal-id: proposal-id, voter-address: tx-sender})))
            (begin
                (map-set voter-participation
                    {proposal-id: proposal-id, voter-address: tx-sender}
                    {vote-decision: support-proposal})
                (map-set governance-proposals
                    {proposal-id: proposal-id}
                    (merge proposal-data
                        {
                            supporting-votes: (+ (get supporting-votes proposal-data) 
                                            (if support-proposal u1 u0)),
                            opposing-votes: (+ (get opposing-votes proposal-data)
                                           (if support-proposal u0 u1))
                        }))
                (ok true))
            ERR-INVALID-GOVERNANCE-PROPOSAL)))

;; Helper Functions

;; Check if a measurement falls within acceptable deviation from consensus
(define-private (check-measurement-validity (actual-value int) (expected-value int))
    (let ((measured-deviation (absolute-value (- actual-value expected-value))))
        (<= (* measured-deviation 100) (* expected-value allowed-consensus-deviation))))

;; Calculate the absolute value of an integer
(define-private (absolute-value (value int))
    (if (< value 0)
        (* value -1)
        value))

;; Read-Only Functions

;; Get detailed information about a registered device
(define-read-only (get-device-details (device-id (string-ascii 24)))
    (map-get? registered-devices {device-id: device-id}))

;; Get weather data submitted by a specific device
(define-read-only (get-device-weather-data (device-id (string-ascii 24)) 
                                        (collection-timestamp uint))
    (map-get? collected-weather-data {device-id: device-id, collection-timestamp: collection-timestamp}))

;; Get consensus data for a region at a specific time
(define-read-only (get-regional-consensus (region-hash (string-ascii 16)) 
                                       (consensus-timestamp uint))
    (map-get? regional-consensus-data {region-hash: region-hash, consensus-timestamp: consensus-timestamp}))

;; Look up device by owner address
(define-read-only (get-device-by-owner-address (owner-address principal))
    (let ((device-id (map-get? device-ownership-registry owner-address)))
        {device-id: (default-to "" device-id)}))

;; Get performance metrics for a device
(define-read-only (get-device-performance (device-id (string-ascii 24)))
    (map-get? device-performance-metrics {device-id: device-id}))

;; Get details about a governance proposal
(define-read-only (get-proposal-details (proposal-id uint))
    (map-get? governance-proposals {proposal-id: proposal-id}))