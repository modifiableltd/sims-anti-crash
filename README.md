# sims-anti-crash
The Sims 4 Anti-Crash system for automatic runtime detection and thermal throttling

# Install process
- Download .zip file and extract to your desired location
- Right-click on `Sims Anti-Crash.exe` and click Properties
- Navigate to the `Compatibility` tab
- Check `Run this program as an administrator`
- Click `OK`
- This should complete the install process

**NOTE: Some Antivirus software(s)/Windows Defender may flag the executable as malware, if this is the case, mark it as afe through your specific anti-viruses control panel, or, failing that, run the unwrapped `Sims Anti-Crash.bat` file instead (as an administrator)**

# Usage
- Run Sims Anti-Crash **before** launching The Sims 4
- Allow time for the app to setup (5-10 seconds max)
- Launch The Sims 4
- Play as normal, no crashes should occur
- Sims Anti-Crash will automatically throttle the CPU depending on CPU temperature and utilization
- Note: crashes may still occur if throttling is ineffective
- Once finished, close the game and wait for the app to detect this closure
- Once the app re-enters standby mode, it is safe to close

# Issues
- Due to thermal control and processor power management systems varying for different computers, this app may not work, or be unstable on certain systems
- Unexpected shudowns with the app open may leave the CPU at a throttled state upon restart, if this is the case, reloading the app and The Sims should reset this to its baseline, failing this, manual alteration of your Windows Advanced Power Management Settings may be required
