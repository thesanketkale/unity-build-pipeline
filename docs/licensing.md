# Unity Build Server Licensing Guide

*Documentation Reference Date: October 2026*  
*Reference Source: [Unity Build Server Licensing Manual](https://docs.unity3d.com/Manual/InstallationLicensing.html)*

---

## Important Legal Disclaimer

This document describes the licensing mechanisms and options provided by Unity Technologies for continuous integration and automated build servers based on publicly available documentation as of October 2026. This document makes no legal claims, warranties, or official representations on behalf of Unity Technologies. Licensing terms and seat compliance requirements vary by organization tier and agreement. **Always review your specific Unity Software License Agreement (EULA) and consult with your Unity account representative regarding your build farm compliance.**

---

## Licensing Options for Build Machines

Unity requires a valid license to execute the Editor in batchmode (`Unity.exe -batchmode`). Unity currently offers three primary licensing models suitable for automated build infrastructure:

### 1. Unity Build Server License (Floating / On-Premise)
- **Target Audience:** Enterprise studios and teams operating dedicated automated build farms.
- **Mechanism:** Utilizes Unity Licensing Server (ULS) or centralized floating license pools. Build jobs lease a build server seat dynamically during execution and release it upon job completion.
- **Advantages:** Build machines do not require static account credentials or individual serial keys; compliant with corporate multi-agent CI clusters.

### 2. Standalone Unity Pro / Enterprise Serial Activation
- **Target Audience:** Small to mid-sized teams running 1 to 3 dedicated build machines.
- **Mechanism:** A dedicated Unity Pro or Enterprise seat is activated directly on the physical host machine using the serial key and Unity ID credentials:
  ```powershell
  pwsh -File .\runner\license.ps1 -Action Activate -Serial "SC-XXXX-..." -Username "ci@company.com" -Password "secret"
  ```
- **Advantages:** Simple to set up on a single dedicated Windows runner without setting up a license server.
- **Considerations:** Consumes one active seat per machine. If rebuilding or decommissioning the physical runner, the license MUST be returned via `license.ps1 -Action Return` to release the seat.

### 3. Unity Personal License
- **Target Audience:** Independent hobbyists and solo developers eligible under Unity Personal tier revenue thresholds (<$100,000 USD revenue in past 12 months).
- **Mechanism:** Activated interactively through Unity Hub by signing into the developer's personal Unity ID.
- **Limitations:** Unity Personal licenses require periodic interactive refresh and cannot be activated headless via pure command-line serial without manual token generation.

---

## Command Line Activation Commands

For automated headless setups, Unity provides command-line flags on the `Unity.exe` binary:

```powershell
# Online Activation
Unity.exe -batchmode -quit -nographics -serial "<SERIAL>" -username "<USERNAME>" -password "<PASSWORD>" -logFile license-activate.log

# Return / Deactivate Seat
Unity.exe -batchmode -quit -nographics -returnlicense -logFile license-return.log
```

Our helper script `runner/license.ps1` wraps these commands with error logging and credential masking.
