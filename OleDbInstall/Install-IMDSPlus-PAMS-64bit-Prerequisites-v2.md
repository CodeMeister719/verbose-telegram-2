# ⚠️ IMPORTANT  
## Administrator Privileges Required

Installing these components requires **Administrator access** on the computer.  
If you do not have admin rights, please contact your **IT Support team** before continuing.

These components install Microsoft system libraries used by IMDSPlus/PAMS and must be installed with elevated permissions.

---

# Overview

This guide installs and verifies the four Microsoft components required for the **64‑bit version of IMDSPlus/PAMS**:

1. **.NET 8 Desktop Runtime**  
2. **Visual C++ Redistributable 2015–2022 (x86)**  
3. **Visual C++ Redistributable 2015–2022 (x64)**  
4. **Microsoft OLE DB Driver 19 for SQL Server**

These components ensure the application can run correctly and connect to SQL Server.

---

# 1. Install .NET 8 Desktop Runtime (Windows Only)

IMDSPlus/PAMS requires the **.NET 8 Desktop Runtime** to run on Windows PCs.

## Step 1 — Download the Runtime

Download from the official Microsoft site:

**.NET 8 Desktop Runtime (Windows)**  
`https://dotnet.microsoft.com/en-us/download/dotnet/8.0` 

On the page, scroll to **Run apps – Runtime** and select:

- **.NET Desktop Runtime 8.x.x (x64)** — for most Windows 10/11 PCs  

> ⚠️ Make sure you choose **Desktop Runtime**, not the SDK or ASP.NET Runtime.

## Step 2 — Install the Runtime

1. Right‑click the downloaded installer  
2. Select **Run as administrator**  
3. Accept the license terms  
4. Click **Install**

The installer writes to `C:\Program Files\dotnet\` and updates system‑wide settings, which requires admin rights.

> **If you see a “Repair” button instead of “Install”:**  
> “No action is needed. .NET 8 Desktop Runtime is already installed. You may close the installer.”

## Step 3 — Verify Installation

Open PowerShell or Command Prompt and run:

```powershell
dotnet --list-runtimes
```

You should see an entry similar to:

```
Microsoft.WindowsDesktop.App 8.0.xx
```

---

# 2. Install Required Visual C++ Redistributables

These redistributables are required by the OLE DB Driver and other Microsoft components.

## Download Links

1. **Visual C++ Redistributable (x86)**  
   `https://aka.ms/vc14/vc_redist.x86.exe`

2. **Visual C++ Redistributable (x64)**  
   `https://aka.ms/vc14/vc_redist.x64.exe`

## Installation Order

1. Run **vc_redist.x86.exe** → click **Install**  
2. Run **vc_redist.x64.exe** → click **Install**  

If either installer shows **Repair**, it means the component is already installed. You may close the installer.

---

# 3. Install Microsoft OLE DB Driver 19 for SQL Server

This driver allows IMDSPlus/PAMS to connect securely to SQL Server databases.

## Download Link

**Microsoft OLE DB Driver 19 for SQL Server**  
`https://go.microsoft.com/fwlink/?linkid=2318101`

## Installation Steps

1. Run **msoledbsql19.msi**  
2. Accept the license agreement  
3. On the **Feature Selection** screen:  
   - ✔️ Keep **OLE DB Driver** selected (required)  
   - ❌ **Uncheck “SDK”** — not needed for end users  
4. Click **Install**  
5. Click **Finish**

> The SDK is only for developers building applications. End users should not install it.

## Restart Required

After installing the OLE DB Driver, **restart your computer** to ensure all components load correctly.

---

# Troubleshooting

### **“Access Denied” or “Administrator Required”**
- The installer must be run as Administrator  
- Contact IT Support if you cannot elevate permissions  

### **Installer Hangs or Freezes**
- Another installation or Windows Update may be running  
- Restart your computer and try again  

### **Components Not Detected After Installation**
- A system restart may be required  
- Restart and verify again  

### **“Repair” Option Appears**
- This means the component is already installed  
- You may continue with the next step  

---

# Contact IT Support

If you encounter issues or do not have administrator privileges, contact your IT Support team.  
Provide:

- A screenshot or description of the error  

Send this information to **REJIS IMDSPlus/PAMS support** for further assistance.

---

# Version Information
as of May 11, 2026
- **.NET 8 Desktop Runtime** 8.0.26
- **OLE DB Driver Version:** 19.4.1
- **VC++ Redistributable:** 2015–2022 (v14.50.xxxxx)

