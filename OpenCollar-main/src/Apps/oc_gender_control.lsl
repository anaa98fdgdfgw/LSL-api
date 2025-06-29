/*
OpenCollar Gender Control and Monitoring Plugin

This script provides advanced access monitoring and awareness features based on gender detection.
It integrates seamlessly with the OpenCollar system and provides menu-driven configuration.

Core Features:
- Access monitoring with gender detection and notifications
- Gender-based access awareness in Public mode with custom messages
- Custom rejection messages for restricted users
- Automatic visibility control for leash states
- RLV gender detection with sensor fallback

Note: This is primarily a monitoring and notification system. It provides awareness
of access attempts and sends feedback to users, rather than hard-blocking core functionality.

Licensed under the GPLv2. See LICENSE for full details.
https://github.com/OpenCollarTeam/OpenCollar
*/

string g_sScriptVersion = "1.0";
string g_sParentMenu = "Apps";
string g_sSubMenu = "Gender Control";

// Settings tokens
string g_sToken = "genderctrl_";

// MESSAGE MAP
integer CMD_OWNER = 500;
integer CMD_TRUSTED = 501;
integer CMD_GROUP = 502;
integer CMD_WEARER = 503;
integer CMD_EVERYONE = 504;
integer CMD_NOACCESS = 599;

integer NOTIFY = 1002;
integer REBOOT = -1000;

integer LM_SETTING_SAVE = 2000;
integer LM_SETTING_REQUEST = 2001;
integer LM_SETTING_RESPONSE = 2002;
integer LM_SETTING_DELETE = 2003;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;

integer AUTH_REQUEST = 600;
integer AUTH_REPLY = 601;

integer RLV_QUERY = 6102;
integer RLV_RESPONSE = 6103;
integer RLV_CMD = 6000;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

// Leash monitoring
integer CMD_PARTICLE = 20000;
integer LEASH_START_MOVEMENT = 20001;
integer LEASH_END_MOVEMENT = 20002;

string UPMENU = "BACK";

// Global variables
key g_kWearer;
list g_lMenuIDs;
integer g_iMenuStride = 3;

// Feature settings
integer g_iMonitoring = TRUE;           // Access monitoring on/off
integer g_iAllowMales = TRUE;           // Allow males in public mode
integer g_iAllowFemales = TRUE;         // Allow females in public mode
integer g_iAutoVisibility = TRUE;       // Auto visibility control
string g_sCustomMessage = "";           // Custom rejection message
integer g_iCollarHidden = FALSE;        // Current collar visibility state
integer g_iOriginalHiddenState = FALSE; // Original state before leashing
integer g_iLeashed = FALSE;             // Current leash state

// Gender detection cache
list g_lGenderCache = [];               // [key, gender, timestamp]
integer g_iCacheTimeout = 300;          // 5 minutes cache timeout
integer g_iRLVActive = FALSE;

// Gender constants
integer GENDER_UNKNOWN = 0;
integer GENDER_MALE = 1;
integer GENDER_FEMALE = 2;

// Detection states
integer g_iDetecting = FALSE;
key g_kDetectTarget;
integer g_iDetectListenerMale;
integer g_iDetectListenerFemale;
integer g_iRLVListener;

// Touch monitoring
integer g_iTouchListener = 0;

integer ALIVE = -55;
integer READY = -56;
integer STARTUP = -57;

Dialog(key kID, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sName) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);

    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, sName], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kID, kMenuID, sName];
}

string Checkbox(integer iValue, string sLabel) {
    if (iValue) return "☑ " + sLabel;
    else return "☐ " + sLabel;
}

MainMenu(key kID, integer iAuth) {
    string sPrompt = "\n[Gender Control & Monitoring]\n\nConfigure access control and monitoring based on gender detection.";
    list lButtons = [
        Checkbox(g_iMonitoring, "Monitoring"),
        "Access Control",
        Checkbox(g_iAutoVisibility, "Auto Visibility")
    ];
    Dialog(kID, sPrompt, lButtons, [UPMENU], 0, iAuth, "Menu~Main");
}

AccessControlMenu(key kID, integer iAuth) {
    string sPrompt = "\n[Access Control Settings]\n\nProvide awareness and feedback for collar access based on gender in Public mode.\nOwners and trustees always have access.\n\nWhen disabled genders access the collar, they receive custom messages.";
    list lButtons = [
        Checkbox(g_iAllowMales, "Allow Males"),
        Checkbox(g_iAllowFemales, "Allow Females"),
        "Custom Message"
    ];
    Dialog(kID, sPrompt, lButtons, [UPMENU], 0, iAuth, "Menu~AccessControl");
}

CustomMessageMenu(key kID, integer iAuth) {
    string sPrompt = "\n[Custom Rejection Message]\n\nCurrent message: ";
    if (g_sCustomMessage == "") sPrompt += "(none)";
    else sPrompt += "\"" + g_sCustomMessage + "\"";
    sPrompt += "\n\nChoose an action:";
    
    list lButtons = [];
    if (g_sCustomMessage != "") lButtons += ["Clear Message"];
    lButtons += ["Set Message"];
    
    Dialog(kID, sPrompt, lButtons, [UPMENU], 0, iAuth, "Menu~CustomMessage");
}

// Gender detection functions
string GetGenderFromCache(key kTarget) {
    integer iIndex = llListFindList(g_lGenderCache, [kTarget]);
    if (iIndex != -1) {
        integer iTimestamp = llList2Integer(g_lGenderCache, iIndex + 2);
        if (llGetUnixTime() - iTimestamp < g_iCacheTimeout) {
            return llList2String(g_lGenderCache, iIndex + 1);
        } else {
            // Remove expired entry
            g_lGenderCache = llDeleteSubList(g_lGenderCache, iIndex, iIndex + 2);
        }
    }
    return "";
}

CacheGender(key kTarget, string sGender) {
    // Remove existing entry if present
    integer iIndex = llListFindList(g_lGenderCache, [kTarget]);
    if (iIndex != -1) {
        g_lGenderCache = llDeleteSubList(g_lGenderCache, iIndex, iIndex + 2);
    }
    
    // Add new entry
    g_lGenderCache += [kTarget, sGender, llGetUnixTime()];
    
    // Keep cache size reasonable (max 20 entries)
    while (llGetListLength(g_lGenderCache) > 60) {
        g_lGenderCache = llDeleteSubList(g_lGenderCache, 0, 2);
    }
}

StartGenderDetection(key kTarget) {
    if (g_iDetecting) return; // Already detecting
    
    g_kDetectTarget = kTarget;
    g_iDetecting = TRUE;
    
    if (g_iRLVActive && kTarget == g_kWearer) {
        // RLV gender detection only works for the wearer
        // Listen for RLV responses on channel 2222
        g_iRLVListener = llListen(2222, "", g_kWearer, "");
        // Send RLV query to check for attachments on pelvis
        llMessageLinked(LINK_SET, RLV_CMD, "getattach:pelvis=2222", "genderdetect");
        llSetTimerEvent(3.0); // Timeout for RLV response
    } else {
        // Go straight to sensor detection for others
        StartSensorDetection();
    }
}

StartSensorDetection() {
    // Scan for genital attachments to determine gender
    g_iDetectListenerMale = llListen(-99999, "", "", "");
    g_iDetectListenerFemale = llListen(-99998, "", "", "");
    
    // Use llSensor to detect nearby objects attached to the target
    llSensor("", g_kDetectTarget, SCRIPTED, 96.0, PI);
}

FinishGenderDetection(string sGender) {
    g_iDetecting = FALSE;
    llSetTimerEvent(0);
    if (g_iDetectListenerMale) {
        llListenRemove(g_iDetectListenerMale);
        g_iDetectListenerMale = 0;
    }
    if (g_iDetectListenerFemale) {
        llListenRemove(g_iDetectListenerFemale);
        g_iDetectListenerFemale = 0;
    }
    if (g_iRLVListener) {
        llListenRemove(g_iRLVListener);
        g_iRLVListener = 0;
    }
    
    CacheGender(g_kDetectTarget, sGender);
    g_kDetectTarget = NULL_KEY;
}

string DetectGender(key kTarget) {
    // Check cache first
    string sCachedGender = GetGenderFromCache(kTarget);
    if (sCachedGender != "") return sCachedGender;
    
    // Start asynchronous detection
    StartGenderDetection(kTarget);
    
    // Return unknown for now, will be cached when detection completes
    return "unknown";
}

integer CheckAccess(key kUser, integer iAuth) {
    // Owners and trustees always have access
    if (iAuth == CMD_OWNER || iAuth == CMD_TRUSTED) return TRUE;
    
    // Only restrict in public mode
    if (iAuth != CMD_EVERYONE) return TRUE;
    
    // If both genders allowed, permit access
    if (g_iAllowMales && g_iAllowFemales) return TRUE;
    
    string sGender = DetectGender(kUser);
    
    if (sGender == "male" && !g_iAllowMales) return FALSE;
    if (sGender == "female" && !g_iAllowFemales) return FALSE;
    
    return TRUE;
}

SendAccessNotification(key kAccessor, string sGender) {
    if (!g_iMonitoring) return;
    
    string sName = llKey2Name(kAccessor);
    string sMessage = "0secondlife:///app/agent/" + (string)kAccessor + "/about (" + sName + ") accessed your collar. Detected gender: " + sGender;
    llMessageLinked(LINK_SET, NOTIFY, sMessage, g_kWearer);
}

SendRejectionMessage(key kUser) {
    if (g_sCustomMessage != "") {
        llMessageLinked(LINK_SET, NOTIFY, "0" + g_sCustomMessage, kUser);
    }
}

MonitorLeashState(string sCommand, key kTarget) {
    if (!g_iAutoVisibility) return;
    
    if (sCommand == "leash" && !g_iLeashed) {
        // Collar is being leashed
        g_iLeashed = TRUE;
        g_iOriginalHiddenState = g_iCollarHidden;
        
        if (g_iCollarHidden) {
            // Make collar visible when leashed
            llMessageLinked(LINK_SET, LM_SETTING_SAVE, "global_hide=0", "");
        }
    } else if (sCommand == "unleash" && g_iLeashed) {
        // Collar is being unleashed
        g_iLeashed = FALSE;
        
        // Restore original visibility state
        if (g_iOriginalHiddenState && !g_iCollarHidden) {
            llMessageLinked(LINK_SET, LM_SETTING_SAVE, "global_hide=1", "");
        }
    }
}

InterceptAccess(key kAccessor, integer iAuth, string sType) {
    // Send monitoring notification
    if (g_iMonitoring && kAccessor != g_kWearer) {
        string sGender = DetectGender(kAccessor);
        SendAccessNotification(kAccessor, sGender);
    }
    
    // Check access control
    if (!CheckAccess(kAccessor, iAuth)) {
        SendRejectionMessage(kAccessor);
        return FALSE; // Block access
    }
    
    return TRUE; // Allow access
}

UserCommand(integer iNum, string sStr, key kID) {
    if (iNum < CMD_OWNER || iNum > CMD_WEARER) return;
    if (llSubStringIndex(llToLower(sStr), llToLower(g_sSubMenu)) && llToLower(sStr) != "menu " + llToLower(g_sSubMenu)) return;
    
    if (llToLower(sStr) == llToLower(g_sSubMenu) || llToLower(sStr) == "menu " + llToLower(g_sSubMenu)) {
        MainMenu(kID, iNum);
    }
}

default {
    on_rez(integer iNum) {
        llResetScript();
    }
    
    state_entry() {
        llMessageLinked(LINK_SET, ALIVE, llGetScriptName(), "");
    }
    
    link_message(integer iSender, integer iNum, string sStr, key kID) {
        if (iNum == REBOOT) {
            if (sStr == "reboot") {
                llResetScript();
            }
        } else if (iNum == READY) {
            llMessageLinked(LINK_SET, ALIVE, llGetScriptName(), "");
        } else if (iNum == STARTUP) {
            state active;
        }
    }
}

state active {
    on_rez(integer t) {
        if (llGetOwner() != g_kWearer) llResetScript();
    }
    
    state_entry() {
        g_kWearer = llGetOwner();
        
        // Request settings
        llMessageLinked(LINK_SET, LM_SETTING_REQUEST, g_sToken + "monitoring", "");
        llMessageLinked(LINK_SET, LM_SETTING_REQUEST, g_sToken + "allowmales", "");
        llMessageLinked(LINK_SET, LM_SETTING_REQUEST, g_sToken + "allowfemales", "");
        llMessageLinked(LINK_SET, LM_SETTING_REQUEST, g_sToken + "autovisibility", "");
        llMessageLinked(LINK_SET, LM_SETTING_REQUEST, g_sToken + "custommessage", "");
        llMessageLinked(LINK_SET, LM_SETTING_REQUEST, "global_hide", "");
        
        // Check RLV status
        llMessageLinked(LINK_SET, RLV_QUERY, "", "");
    }
    
    timer() {
        if (g_iDetecting) {
            // Detection timeout, fall back to sensor or finish
            if (g_iRLVListener) {
                // RLV detection timeout, fall back to sensor
                if (g_iRLVListener) {
                    llListenRemove(g_iRLVListener);
                    g_iRLVListener = 0;
                }
                StartSensorDetection();
            } else {
                // Sensor detection timeout
                FinishGenderDetection("unknown");
            }
        } else {
            // Custom message input timeout
            llSetTimerEvent(0);
        }
    }
    
    sensor(integer iNum) {
        // Analyze detected objects for gender determination
        integer i;
        integer iMaleIndicators = 0;
        integer iFemaleIndicators = 0;
        
        for (i = 0; i < iNum; i++) {
            string sName = llToLower(llDetectedName(i));
            key kOwner = llDetectedOwner(i);
            
            if (kOwner == g_kDetectTarget) {
                // Check for male indicators
                if (llSubStringIndex(sName, "penis") != -1 || 
                    llSubStringIndex(sName, "cock") != -1 ||
                    llSubStringIndex(sName, "male") != -1) {
                    iMaleIndicators++;
                }
                
                // Check for female indicators
                if (llSubStringIndex(sName, "vagina") != -1 || 
                    llSubStringIndex(sName, "pussy") != -1 ||
                    llSubStringIndex(sName, "breast") != -1 ||
                    llSubStringIndex(sName, "female") != -1) {
                    iFemaleIndicators++;
                }
            }
        }
        
        string sDetectedGender = "unknown";
        if (iMaleIndicators > iFemaleIndicators) sDetectedGender = "male";
        else if (iFemaleIndicators > iMaleIndicators) sDetectedGender = "female";
        
        FinishGenderDetection(sDetectedGender);
    }
    
    no_sensor() {
        FinishGenderDetection("unknown");
    }
    
    touch_start(integer iNum) {
        // Monitor all touch events for comprehensive logging
        integer i;
        for (i = 0; i < iNum; i++) {
            key kToucher = llDetectedKey(i);
            if (kToucher != g_kWearer && g_iMonitoring) {
                string sGender = DetectGender(kToucher);
                SendAccessNotification(kToucher, sGender);
            }
        }
    }
    
    link_message(integer iSender, integer iNum, string sStr, key kID) {
        if (iNum >= CMD_OWNER && iNum <= CMD_WEARER) {
            UserCommand(iNum, sStr, kID);
        } else if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu) {
            llMessageLinked(iSender, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
        } else if (iNum == RLV_RESPONSE) {
            g_iRLVActive = (sStr == "ON");
        } else if (iNum == CMD_PARTICLE) {
            // Monitor leash state changes
            string sCommand = llList2String(llParseString2List(sStr, ["|"], []), 0);
            MonitorLeashState(sCommand, kID);
        } else if (iNum == 0 && sStr == "menu") {
            // Intercept touch-based menu access
            if (!InterceptAccess(kID, CMD_EVERYONE, "touch")) {
                return; // Block access
            }
        } else if (iNum == AUTH_REQUEST) {
            // Intercept authentication requests for command monitoring
            if (!InterceptAccess(kID, CMD_EVERYONE, "command")) {
                // Could block here, but we'll let auth system handle it for now
                // and just do monitoring
            }
        } else if (iNum == DIALOG_RESPONSE) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (iMenuIndex != -1) {
                string sMenu = llList2String(g_lMenuIDs, iMenuIndex + 1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = llList2Key(lMenuParams, 0);
                string sMsg = llList2String(lMenuParams, 1);
                integer iAuth = llList2Integer(lMenuParams, 3);
                
                if (sMenu == "Menu~Main") {
                    if (sMsg == UPMENU) {
                        llMessageLinked(LINK_SET, iAuth, "menu " + g_sParentMenu, kAv);
                    } else if (sMsg == Checkbox(g_iMonitoring, "Monitoring")) {
                        g_iMonitoring = !g_iMonitoring;
                        if (g_iMonitoring) {
                            llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sToken + "monitoring=1", "");
                        } else {
                            llMessageLinked(LINK_SET, LM_SETTING_DELETE, g_sToken + "monitoring", "");
                        }
                        MainMenu(kAv, iAuth);
                    } else if (sMsg == "Access Control") {
                        AccessControlMenu(kAv, iAuth);
                    } else if (sMsg == Checkbox(g_iAutoVisibility, "Auto Visibility")) {
                        g_iAutoVisibility = !g_iAutoVisibility;
                        if (g_iAutoVisibility) {
                            llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sToken + "autovisibility=1", "");
                        } else {
                            llMessageLinked(LINK_SET, LM_SETTING_DELETE, g_sToken + "autovisibility", "");
                        }
                        MainMenu(kAv, iAuth);
                    }
                } else if (sMenu == "Menu~AccessControl") {
                    if (sMsg == UPMENU) {
                        MainMenu(kAv, iAuth);
                    } else if (sMsg == Checkbox(g_iAllowMales, "Allow Males")) {
                        g_iAllowMales = !g_iAllowMales;
                        if (g_iAllowMales) {
                            llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sToken + "allowmales=1", "");
                        } else {
                            llMessageLinked(LINK_SET, LM_SETTING_DELETE, g_sToken + "allowmales", "");
                        }
                        AccessControlMenu(kAv, iAuth);
                    } else if (sMsg == Checkbox(g_iAllowFemales, "Allow Females")) {
                        g_iAllowFemales = !g_iAllowFemales;
                        if (g_iAllowFemales) {
                            llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sToken + "allowfemales=1", "");
                        } else {
                            llMessageLinked(LINK_SET, LM_SETTING_DELETE, g_sToken + "allowfemales", "");
                        }
                        AccessControlMenu(kAv, iAuth);
                    } else if (sMsg == "Custom Message") {
                        CustomMessageMenu(kAv, iAuth);
                    }
                } else if (sMenu == "Menu~CustomMessage") {
                    if (sMsg == UPMENU) {
                        AccessControlMenu(kAv, iAuth);
                    } else if (sMsg == "Clear Message") {
                        g_sCustomMessage = "";
                        llMessageLinked(LINK_SET, LM_SETTING_DELETE, g_sToken + "custommessage", "");
                        llMessageLinked(LINK_SET, NOTIFY, "0Custom rejection message cleared.", kAv);
                        CustomMessageMenu(kAv, iAuth);
                    } else if (sMsg == "Set Message") {
                        llMessageLinked(LINK_SET, NOTIFY, "0Type your custom rejection message in local chat. It will be sent to users whose gender is disabled.", kAv);
                        llListen(0, "", kAv, "");
                        llSetTimerEvent(30.0); // 30 second timeout for message input
                    }
                }
            }
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex + 3);
        } else if (iNum == LM_SETTING_RESPONSE) {
            list lSettings = llParseString2List(sStr, ["_", "="], []);
            string sToken = llList2String(lSettings, 0);
            string sVar = llList2String(lSettings, 1);
            string sVal = llList2String(lSettings, 2);
            
            if (sToken == "genderctrl") {
                if (sVar == "monitoring") {
                    g_iMonitoring = (integer)sVal;
                } else if (sVar == "allowmales") {
                    g_iAllowMales = (integer)sVal;
                } else if (sVar == "allowfemales") {
                    g_iAllowFemales = (integer)sVal;
                } else if (sVar == "autovisibility") {
                    g_iAutoVisibility = (integer)sVal;
                } else if (sVar == "custommessage") {
                    g_sCustomMessage = sVal;
                }
            } else if (sToken == "global") {
                if (sVar == "hide") {
                    g_iCollarHidden = (integer)sVal;
                }
            }
        }
    }
    
    listen(integer iChannel, string sName, key kSpeaker, string sMessage) {
        if (iChannel == 0 && kSpeaker != g_kWearer) {
            // Custom message input
            g_sCustomMessage = sMessage;
            llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sToken + "custommessage=" + sMessage, "");
            llMessageLinked(LINK_SET, NOTIFY, "0Custom rejection message set to: \"" + sMessage + "\"", kSpeaker);
            llSetTimerEvent(0);
        } else if (iChannel == 2222 && kSpeaker == g_kWearer) {
            // RLV response for gender detection
            string sGender = "unknown";
            if (sMessage != "") {
                // Parse attachment names to determine gender
                list lAttachments = llParseString2List(sMessage, [","], []);
                integer i;
                integer iMaleCount = 0;
                integer iFemaleCount = 0;
                
                for (i = 0; i < llGetListLength(lAttachments); i++) {
                    string sAttach = llToLower(llList2String(lAttachments, i));
                    if (llSubStringIndex(sAttach, "penis") != -1 || 
                        llSubStringIndex(sAttach, "cock") != -1 ||
                        llSubStringIndex(sAttach, "male") != -1) {
                        iMaleCount++;
                    } else if (llSubStringIndex(sAttach, "vagina") != -1 || 
                               llSubStringIndex(sAttach, "pussy") != -1 ||
                               llSubStringIndex(sAttach, "female") != -1) {
                        iFemaleCount++;
                    }
                }
                
                if (iMaleCount > iFemaleCount) sGender = "male";
                else if (iFemaleCount > iMaleCount) sGender = "female";
            }
            
            FinishGenderDetection(sGender);
        }
    }
}