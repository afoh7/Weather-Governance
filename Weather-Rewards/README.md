# Weather Data Oracle Smart Contract

## Overview

The Weather Data Oracle is a decentralized smart contract system built on the Stacks blockchain that enables IoT weather devices to register, submit meteorological data, and receive rewards based on data accuracy and consistency. The system implements a sophisticated consensus mechanism to validate weather readings across regions and includes a governance system for parameter adjustments.

## Features

- **Device Registration**: Register weather data collection devices with geolocation
- **Staking Mechanism**: Stake STX tokens to boost device reputation and eligibility
- **Data Submission**: Submit temperature, humidity, pressure, and wind speed measurements
- **Consensus Validation**: Validate data against regional averages to ensure accuracy
- **Reward Distribution**: Receive STX tokens for validated data submissions
- **Quality Controls**: Penalties for inaccurate data and inactive devices
- **Governance System**: Propose and vote on parameter changes to the system

## Contract Constants

| Parameter | Value | Description |
|-----------|-------|-------------|
| Minimum Stake | 100 STX | Required stake to fully participate |
| Data Submission Reward | 1 STX | Reward per valid data submission |
| Consensus Deviation | 10% | Maximum allowed deviation from consensus |
| Required Validators | 3 | Minimum validators for consensus |
| Accuracy Threshold | 80% | Minimum required accuracy score |
| Device Penalty | 10 STX | Penalty for malfunctioning devices |
| Inactivity Limit | 1440 blocks | Maximum blocks without submission |
| Proposal Approval | 75% | Threshold for governance proposal approval |

## Getting Started

### Prerequisites

- Stacks wallet with STX tokens for device registration and staking
- IoT weather monitoring device with internet connectivity
- Knowledge of device's geographical coordinates

### Device Registration

1. Call the `register-new-device` function with:
   - Device ID (24 character ASCII string)
   - Device latitude (integer)
   - Device longitude (integer)

```clarity
(contract-call? .weather-data-oracle register-new-device "DEVICE001" 37482900 -122235800)
```

2. Stake tokens to your device:

```clarity
(contract-call? .weather-data-oracle add-stake-to-device "DEVICE001" u100000000)
```

### Submitting Weather Data

Submit data from your device with:

```clarity
(contract-call? .weather-data-oracle submit-weather-data 
  "DEVICE001"          ;; device-id
  u1648152000          ;; timestamp 
  i235                 ;; temperature (23.5°C)
  u67                  ;; humidity (67%)
  u101325              ;; pressure (1013.25 hPa)
  u15                  ;; wind speed (15 km/h)
)
```

### Data Validation

Data is validated against regional consensus:

```clarity
(contract-call? .weather-data-oracle validate-submitted-data 
  "DEVICE001"          ;; device-id
  u1648152000          ;; timestamp
  "SF-BAY-AREA-01"     ;; region hash
)
```

## Governance Participation

### Creating a Proposal

To propose a parameter change:

```clarity
(contract-call? .weather-data-oracle create-governance-proposal
  "Increase Rewards"                           ;; title
  "Increase data submission rewards to 1.5 STX" ;; description
  "reward-amount"                              ;; parameter
  u1500000                                     ;; proposed value (1.5 STX)
)
```

### Voting on Proposals

Cast your vote on active proposals:

```clarity
(contract-call? .weather-data-oracle vote-on-governance-proposal u1 true)
```

## Read-Only Functions

Query contract data with these read-only functions:

- `get-device-details`: Get information about a specific device
- `get-device-weather-data`: Retrieve weather data submissions
- `get-regional-consensus`: Get consensus values for a region
- `get-device-by-owner-address`: Look up devices by owner
- `get-device-performance`: Get performance metrics for a device
- `get-proposal-details`: Get details about governance proposals

## Error Codes

| Code | Description |
|------|-------------|
| 401 | Unauthorized access |
| 402 | Device already exists |
| 403 | Insufficient stake amount |
| 404 | Device not registered |
| 405 | Invalid submission data |
| 406 | Consensus validation failed |
| 407 | Accuracy below threshold |
| 408 | Device inactive |
| 409 | Stake requirement not met |
| 410 | Invalid governance proposal |

## Best Practices

1. Ensure device calibration before registration
2. Regularly submit data to avoid inactivity penalties
3. Stake more than the minimum for better governance weight
4. Verify your regional consensus before submission
5. Participate in governance to shape system parameters

## Security Considerations

- Private keys controlling registered devices should be securely stored
- Regular monitoring of device performance metrics is recommended
- Consider implementing additional off-chain validation before submission