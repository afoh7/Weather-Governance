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
(define-constant ERR-INVALID-INPUT (err u411))

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

;; Helper Functions for Input Validation

;; Validate device ID format
(define-private (is-valid-device-id (device-id (string-ascii 24)))
    (and 
        (>= (len device-id) u3)
        (<= (len device-id) u24)))

;; Validate temperature range (-100 to 100 degrees)
(define-private (is-valid-temperature (temp int))
    (and (>= temp -100) (<= temp 100)))

;; Validate humidity range (0-100%)
(define-private (is-valid-humidity (humidity uint))
    (<= humidity u100))

;; Validate pressure range (800-1200 hPa)
(define-private (is-valid-pressure (pressure uint))
    (and (>= pressure u800) (<= pressure u1200)))

;; Validate wind speed (0-200 km/h)
(define-private (is-valid-wind-speed (wind-speed uint))
    (<= wind-speed u200))

;; Validate coordinates
(define-private (is-valid-coordinates (latitude int) (longitude int))
    (and 
        (>= latitude -90) (<= latitude 90)
        (>= longitude -180) (<= longitude 180)))

;; Validate proposal title
(define-private (is-valid-proposal-title (title (string-ascii 50)))
    (and 
        (>= (len title) u5)
        (<= (len title) u50)))

;; Validate proposal description
(define-private (is-valid-proposal-description (description (string-ascii 500)))
    (and 
        (>= (len description) u10)
        (<= (len description) u500)))

;; Validate parameter name
(define-private (is-valid-parameter-name (param (string-ascii 20)))
    (and 
        (>= (len param) u3)
        (<= (len param) u20)))

;; Validate timestamp (must be in a reasonable range)
(define-private (is-valid-timestamp (timestamp uint))
    (and 
        (>= timestamp u1000000000)  ;; Reasonable lower bound (around 2001)
        (<= timestamp u9999999999))) ;; Reasonable upper bound (around 2286)

;; Validate proposal ID
(define-private (is-valid-proposal-id (id uint))
    (and 
        (> id u0)
        (<= id (var-get governance-proposal-counter))))

;; Validate proposed value (generic range check)
(define-private (is-valid-proposed-value (value uint))
    (<= value u1000000000000)) ;; Upper limit to prevent overflow

;; Register a new weather data collection device
(define-public (register-new-device 
                (device-id-input (string-ascii 24)) 
                (device-latitude-input int)
                (device-longitude-input int))
    (begin
        ;; Validate inputs
        (asserts! (is-valid-device-id device-id-input) ERR-INVALID-INPUT)
        (asserts! (is-valid-coordinates device-latitude-input device-longitude-input) ERR-INVALID-INPUT)
        
        (let 
            (
                (existing-device-check (map-get? registered-devices {device-id: device-id-input}))
            )
            (asserts! (is-none existing-device-check) ERR-DEVICE-ALREADY-EXISTS)
            
            (map-set registered-devices
                {device-id: device-id-input}
                {
                    device-owner: tx-sender,
                    staked-amount: u0,
                    device-accuracy: u100,
                    submission-count: u0,
                    device-location: {
                        device-latitude: device-latitude-input,
                        device-longitude: device-longitude-input
                    }
                })
            (map-set device-performance-metrics
                {device-id: device-id-input}
                {
                    last-active-block: block-height,
                    successful-validations: u0,
                    total-earned-rewards: u0,
                    total-incurred-penalties: u0
                })
            (map-set device-ownership-registry tx-sender device-id-input)
            (ok true)
        )
    )
)

;; Stake tokens to increase device reputation and eligibility
(define-public (add-stake-to-device (device-id-input (string-ascii 24)) (stake-amount uint))
    (begin
        ;; Validate inputs
        (asserts! (is-valid-device-id device-id-input) ERR-INVALID-INPUT)
        
        (let 
            (
                (device-data (unwrap! (map-get? registered-devices {device-id: device-id-input}) ERR-DEVICE-NOT-REGISTERED))
            )
            (asserts! (is-eq tx-sender (get device-owner device-data)) ERR-UNAUTHORIZED-ACCESS)
            (asserts! (>= stake-amount required-minimum-stake) ERR-INSUFFICIENT-STAKE-AMOUNT)
            
            (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
            (map-set registered-devices
                {device-id: device-id-input}
                (merge device-data {staked-amount: (+ (get staked-amount device-data) stake-amount)}))
            (ok true)
        )
    )
)

;; Data Submission Functions

;; Submit weather data collected by a device
(define-public (submit-weather-data 
               (device-id-input (string-ascii 24))
               (collection-timestamp-input uint)
               (recorded-temperature-input int)
               (recorded-humidity-input uint)
               (recorded-pressure-input uint)
               (recorded-wind-speed-input uint))
    (begin
        ;; Validate inputs
        (asserts! (is-valid-device-id device-id-input) ERR-INVALID-INPUT)
        (asserts! (is-valid-timestamp collection-timestamp-input) ERR-INVALID-INPUT)
        (asserts! (is-valid-temperature recorded-temperature-input) ERR-INVALID-SUBMISSION-DATA)
        (asserts! (is-valid-humidity recorded-humidity-input) ERR-INVALID-SUBMISSION-DATA)
        (asserts! (is-valid-pressure recorded-pressure-input) ERR-INVALID-SUBMISSION-DATA)
        (asserts! (is-valid-wind-speed recorded-wind-speed-input) ERR-INVALID-SUBMISSION-DATA)
        
        (let 
            (
                (device-data (unwrap! (map-get? registered-devices {device-id: device-id-input}) ERR-DEVICE-NOT-REGISTERED))
                (device-metrics (default-to 
                                {
                                    last-active-block: u0,
                                    successful-validations: u0,
                                    total-earned-rewards: u0,
                                    total-incurred-penalties: u0
                                }
                                (map-get? device-performance-metrics {device-id: device-id-input})))
            )
            (asserts! (is-eq tx-sender (get device-owner device-data)) ERR-UNAUTHORIZED-ACCESS)
            
            (map-set collected-weather-data
                {
                    device-id: device-id-input,
                    collection-timestamp: collection-timestamp-input
                }
                {
                    recorded-temperature: recorded-temperature-input,
                    recorded-humidity: recorded-humidity-input,
                    recorded-pressure: recorded-pressure-input,
                    recorded-wind-speed: recorded-wind-speed-input,
                    data-validation-status: false
                })
            (map-set device-performance-metrics
                {device-id: device-id-input}
                (merge device-metrics {last-active-block: block-height}))
            (map-set registered-devices
                {device-id: device-id-input}
                (merge device-data 
                    {submission-count: (+ (get submission-count device-data) u1)}))
            (ok true)
        )
    )
)

;; Data Validation Functions

;; Validate submitted data against regional consensus
(define-public (validate-submitted-data 
               (device-id-input (string-ascii 24))
               (collection-timestamp-input uint)
               (region-hash (string-ascii 16)))
    (begin
        ;; Validate inputs
        (asserts! (is-valid-device-id device-id-input) ERR-INVALID-INPUT)
        (asserts! (is-valid-timestamp collection-timestamp-input) ERR-INVALID-INPUT)
        
        (let 
            (
                (submission-data (unwrap! (map-get? collected-weather-data 
                                    {device-id: device-id-input, collection-timestamp: collection-timestamp-input})
                                    ERR-DEVICE-NOT-REGISTERED))
                (consensus-check (map-get? regional-consensus-data 
                                {region-hash: region-hash, consensus-timestamp: collection-timestamp-input}))
                (device-data (unwrap! (map-get? registered-devices {device-id: device-id-input})
                                ERR-DEVICE-NOT-REGISTERED))
                (device-metrics (unwrap! (map-get? device-performance-metrics {device-id: device-id-input})
                                      ERR-DEVICE-NOT-REGISTERED))
            )
            (asserts! (is-some consensus-check) ERR-INVALID-SUBMISSION-DATA)
            
            (let 
                (
                    (regional-data (unwrap-panic consensus-check))
                )
                (asserts! 
                    (and
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
                    ERR-CONSENSUS-VALIDATION-FAILED)
                
                (try! (as-contract 
                    (stx-transfer? data-submission-reward contract-administrator 
                                (get device-owner device-data))))
                (map-set collected-weather-data
                    {device-id: device-id-input, collection-timestamp: collection-timestamp-input}
                    (merge submission-data {data-validation-status: true}))
                (map-set device-performance-metrics
                    {device-id: device-id-input}
                    (merge device-metrics 
                        {
                            successful-validations: (+ (get successful-validations device-metrics) u1),
                            total-earned-rewards: (+ (get total-earned-rewards device-metrics) data-submission-reward)
                        }))
                (ok true)
            )
        )
    )
)

;; Quality Control Functions

;; Report a malfunctioning device
(define-public (report-device-malfunction (device-id-input (string-ascii 24)))
    (begin
        ;; Validate inputs
        (asserts! (is-valid-device-id device-id-input) ERR-INVALID-INPUT)
        
        (let 
            (
                (device-data (unwrap! (map-get? registered-devices {device-id: device-id-input})
                                ERR-DEVICE-NOT-REGISTERED))
                (device-metrics (unwrap! (map-get? device-performance-metrics {device-id: device-id-input})
                                      ERR-DEVICE-NOT-REGISTERED))
            )
            (asserts! (< (get device-accuracy device-data) minimum-accuracy-threshold) ERR-INVALID-SUBMISSION-DATA)
            
            (try! (as-contract 
                (stx-transfer? device-penalty-amount 
                            (get device-owner device-data)
                            contract-administrator)))
            (map-set device-performance-metrics
                {device-id: device-id-input}
                (merge device-metrics 
                    {total-incurred-penalties: (+ (get total-incurred-penalties device-metrics) u1)}))
            (ok true)
        )
    )
)

;; Update device status based on activity
(define-public (update-device-activity-status (device-id-input (string-ascii 24)))
    (begin
        ;; Validate inputs
        (asserts! (is-valid-device-id device-id-input) ERR-INVALID-INPUT)
        
        (let 
            (
                (device-data (unwrap! (map-get? registered-devices {device-id: device-id-input})
                                ERR-DEVICE-NOT-REGISTERED))
                (device-metrics (unwrap! (map-get? device-performance-metrics {device-id: device-id-input})
                                      ERR-DEVICE-NOT-REGISTERED))
            )
            (asserts! (> (- block-height (get last-active-block device-metrics)) 
                        device-inactivity-limit) ERR-INVALID-SUBMISSION-DATA)
            
            (map-set registered-devices
                {device-id: device-id-input}
                (merge device-data {device-accuracy: u0}))
            (ok true)
        )
    )
)

;; Governance Functions

;; Create a new governance proposal
(define-public (create-governance-proposal 
    (proposal-title-input (string-ascii 50))
    (proposal-description-input (string-ascii 500))
    (target-parameter-input (string-ascii 20))
    (proposed-value-input uint))
    (begin
        ;; Validate inputs
        (asserts! (is-valid-proposal-title proposal-title-input) ERR-INVALID-INPUT)
        (asserts! (is-valid-proposal-description proposal-description-input) ERR-INVALID-INPUT)
        (asserts! (is-valid-parameter-name target-parameter-input) ERR-INVALID-INPUT)
        (asserts! (is-valid-proposed-value proposed-value-input) ERR-INVALID-INPUT)
        
        (let 
            (
                (new-proposal-id (+ (var-get governance-proposal-counter) u1))
                (device-id (unwrap! (map-get? device-ownership-registry tx-sender)
                                  ERR-UNAUTHORIZED-ACCESS))
                (device-data (unwrap! (map-get? registered-devices {device-id: device-id})
                                ERR-UNAUTHORIZED-ACCESS))
            )
            (asserts! (>= (get staked-amount device-data) (* required-minimum-stake u2)) ERR-STAKE-REQUIREMENT-NOT-MET)
            
            (map-set governance-proposals
                {proposal-id: new-proposal-id}
                {
                    proposal-creator: tx-sender,
                    proposal-title: proposal-title-input,
                    proposal-description: proposal-description-input,
                    target-parameter: target-parameter-input,
                    proposed-value: proposed-value-input,
                    supporting-votes: u0,
                    opposing-votes: u0,
                    proposal-status: "active",
                    voting-deadline: (+ block-height u1440)
                })
            (var-set governance-proposal-counter new-proposal-id)
            (ok new-proposal-id)
        )
    )
)

;; Cast vote on an active governance proposal
(define-public (vote-on-governance-proposal (proposal-id-input uint) (support-proposal bool))
    (begin
        ;; Validate inputs
        (asserts! (is-valid-proposal-id proposal-id-input) ERR-INVALID-GOVERNANCE-PROPOSAL)
        
        (let 
            (
                (proposal-data (unwrap! (map-get? governance-proposals {proposal-id: proposal-id-input})
                                  ERR-INVALID-GOVERNANCE-PROPOSAL))
                (device-id (unwrap! (map-get? device-ownership-registry tx-sender)
                                  ERR-UNAUTHORIZED-ACCESS))
                (device-data (unwrap! (map-get? registered-devices {device-id: device-id})
                                ERR-UNAUTHORIZED-ACCESS))
                (voter-check (map-get? voter-participation 
                                    {proposal-id: proposal-id-input, voter-address: tx-sender}))
            )
            (asserts! (is-eq (get proposal-status proposal-data) "active") ERR-INVALID-GOVERNANCE-PROPOSAL)
            (asserts! (< block-height (get voting-deadline proposal-data)) ERR-INVALID-GOVERNANCE-PROPOSAL)
            (asserts! (is-none voter-check) ERR-INVALID-GOVERNANCE-PROPOSAL)
            
            (map-set voter-participation
                {proposal-id: proposal-id-input, voter-address: tx-sender}
                {vote-decision: support-proposal})
            (map-set governance-proposals
                {proposal-id: proposal-id-input}
                (merge proposal-data
                    {
                        supporting-votes: (+ (get supporting-votes proposal-data) 
                                        (if support-proposal u1 u0)),
                        opposing-votes: (+ (get opposing-votes proposal-data)
                                       (if support-proposal u0 u1))
                    }))
            (ok true)
        )
    )
)

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
(define-read-only (get-device-details (device-id-input (string-ascii 24)))
    (begin
        (if (is-valid-device-id device-id-input)
            (map-get? registered-devices {device-id: device-id-input})
            none)
    )
)

;; Get weather data submitted by a specific device
(define-read-only (get-device-weather-data 
                  (device-id-input (string-ascii 24)) 
                  (collection-timestamp-input uint))
    (begin
        (if (and 
                (is-valid-device-id device-id-input)
                (is-valid-timestamp collection-timestamp-input))
            (map-get? collected-weather-data {device-id: device-id-input, collection-timestamp: collection-timestamp-input})
            none)
    )
)

;; Get consensus data for a region at a specific time
(define-read-only (get-regional-consensus 
                  (region-hash (string-ascii 16)) 
                  (consensus-timestamp-input uint))
    (begin
        (if (is-valid-timestamp consensus-timestamp-input)
            (map-get? regional-consensus-data {region-hash: region-hash, consensus-timestamp: consensus-timestamp-input})
            none)
    )
)

;; Look up device by owner address
(define-read-only (get-device-by-owner-address (owner-address principal))
    (let ((device-id (map-get? device-ownership-registry owner-address)))
        {device-id: (default-to "" device-id)}
    )
)

;; Get performance metrics for a device
(define-read-only (get-device-performance (device-id-input (string-ascii 24)))
    (begin
        (if (is-valid-device-id device-id-input)
            (map-get? device-performance-metrics {device-id: device-id-input})
            none)
    )
)

;; Get details about a governance proposal
(define-read-only (get-proposal-details (proposal-id-input uint))
    (begin
        (if (is-valid-proposal-id proposal-id-input)
            (map-get? governance-proposals {proposal-id: proposal-id-input})
            none)
    )
)