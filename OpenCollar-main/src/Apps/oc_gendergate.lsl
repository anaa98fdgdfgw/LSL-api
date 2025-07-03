// This file is part of OpenCollar.
// Created for gender based access control
// Licensed under GPLv2. See LICENSE for details.

string g_sParentMenu = "Apps";
string g_sSubMenu = "GenderGate";
string LSDPrefix = "gendergate";

integer CMD_OWNER = 500;
integer CMD_TRUSTED = 501;
integer CMD_GROUP = 502;
integer CMD_WEARER = 503;
integer CMD_EVERYONE = 504;
integer CMD_BLOCKED = 598;
integer CMD_NOACCESS = 599;

integer NOTIFY = 1002;
integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer LM_SETTING_RESPONSE = 2002;
integer CMD_PARTICLE = 20000;

string UPMENU = "BACK";

key g_kWearer;
integer g_iNotify = TRUE;            // send wearer a message on access attempt
integer g_iAllowedGender = 2;        // 0 male,1 female,2 both
string g_sDeniedMsg = "";            // message sent to denied user
integer g_iHideState;                // current collar hide state
integer g_iRestoreHide = FALSE;      // track hide restore after leash

// gender detection helpers
float SCAN_RANGE = 20.0;
float SCAN_TIME  = 30.0;
integer g_iScanner;                  // sensor running handle
key g_kScanTarget;                   // current rlv scan target
integer g_iRlvChan;                  // channel used for rlv @getgender
integer g_iRlvHandle;                // listener handle
list g_lMaleKeys = ["signature","jake","gianni","legacy male","apollo","niramyth"];
list g_lFemaleKeys = ["maitreya","legacy","kupra","freya","lara","isis","venus","belleza","slink","inithium"];

string LSDRead(string token){
    return llLinksetDataRead(LSDPrefix+"_"+token);
}

LSDWrite(string token, string val){
    llLinksetDataWrite(LSDPrefix+"_"+token,val);
}

integer ContainsAny(string str, list keys){
    str = llToLower(str);
    integer i;
    for(i=0;i<llGetListLength(keys);++i){
        if(~llSubStringIndex(str,llList2String(keys,i))) return TRUE;
    }
    return FALSE;
}

integer GetCachedGender(key kAv){
    string s = llLinksetDataRead(LSDPrefix+"_gender_"+(string)kAv);
    if(s!="") return (integer)s;
    return 2;
}

SetCachedGender(key kAv, integer g){
    llLinksetDataWrite(LSDPrefix+"_gender_"+(string)kAv,(string)g);
}

integer GetGender(key kAv){
    integer g = GetCachedGender(kAv);
    if(g != 2) return g;

    g_kScanTarget = kAv;
    g_iRlvChan = -(1000 + (integer)llFrand(1000000.0));
    g_iRlvHandle = llListen(g_iRlvChan,"",kAv,"");
    llRegionSayTo(kAv,g_iRlvChan,"@getgender="+(string)g_iRlvChan);
    llSetTimerEvent(5.0);
    return 2; // unknown until response or scan
}

ShowCollar(){
    llMessageLinked(LINK_SET, CMD_OWNER, "show", g_kWearer);
}
HideCollar(){
    llMessageLinked(LINK_SET, CMD_OWNER, "hide", g_kWearer);
}

mainMenu(key kAv, integer iAuth){
    list buttons;
    if(g_iNotify) buttons += ["▣ Notify"];
    else buttons += ["☐ Notify"];
    if(g_iAllowedGender==0) buttons += ["♂ Only"];
    else if(g_iAllowedGender==1) buttons += ["♀ Only"];
    else buttons += ["♂♀ Both"];
    buttons += ["Message"];
    Dialog(kAv, "GenderGate settings", buttons, [UPMENU], 0, iAuth, "main");
}

Dialog(key kID, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sName){
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kID+"|"+sPrompt+"|"+(string)iPage+"|"+llDumpList2String(lChoices,"`")+"|"+llDumpList2String(lUtilityButtons,"`")+"|"+(string)iAuth, kMenuID);
    g_lMenuIDs += [kID, kMenuID, sName];
}

list g_lMenuIDs;
integer g_iMenuStride = 3;

default{
    state_entry(){
        g_kWearer = llGetOwner();
        string s;
        s = LSDRead("notify"); if(s!="") g_iNotify=(integer)s; else LSDWrite("notify","1");
        s = LSDRead("allowed"); if(s!="") g_iAllowedGender=(integer)s; else LSDWrite("allowed","2");
        g_sDeniedMsg = LSDRead("message");
        g_iHideState = (integer)llLinksetDataRead("global_hide");
        llSensorRepeat("","",SCRIPTED|PASSIVE,SCAN_RANGE,PI,SCAN_TIME);
    }

    on_rez(integer p){ llResetScript(); }

    sensor(integer n){
        integer i;
        for(i=0;i<n;i++){
            key owner = llDetectedOwner(i);
            if(owner != g_kWearer){ // ignore wearer attachments
                if(GetCachedGender(owner) == 2){
                    integer gender = 2;
                    string name = llDetectedName(i);
                    if(ContainsAny(name, g_lFemaleKeys)) gender = 1;
                    else if(ContainsAny(name, g_lMaleKeys)) gender = 0;
                    if(gender != 2) SetCachedGender(owner, gender);
                }
            }
        }
    }

    listen(integer chan,string name,key id,string msg){
        if(chan==g_iRlvChan && id==g_kScanTarget){
            llListenRemove(g_iRlvHandle); g_iRlvHandle=0;
            integer gender = 2;
            string l = llToLower(msg);
            if(l=="male") gender=0;
            else if(l=="female") gender=1;
            if(gender!=2) SetCachedGender(id,gender);
            else llSensor("","",SCRIPTED|PASSIVE,SCAN_RANGE,PI);
            g_kScanTarget=NULL_KEY;
            llSetTimerEvent(0);
        }
    }

    timer(){
        if(g_kScanTarget){
            llListenRemove(g_iRlvHandle); g_iRlvHandle=0;
            llSensor("","",SCRIPTED|PASSIVE,SCAN_RANGE,PI);
        }
        llSetTimerEvent(0);
    }

    link_message(integer iSender, integer iNum, string sStr, key kID){
        if(iNum >= CMD_OWNER && iNum <= CMD_EVERYONE){
            if(llToLower(llGetSubString(sStr,0,3)) == "menu"){
                if(g_iNotify) llRegionSayTo(g_kWearer,0,"Menu access by "+llKey2Name(kID));
                if(iNum > CMD_TRUSTED){
                    integer g = GetGender(kID);
                    if(g_iAllowedGender != 2 && g != 2){
                        if((g_iAllowedGender==0 && g==1) || (g_iAllowedGender==1 && g==0)){
                            if(g_sDeniedMsg!="") llRegionSayTo(kID,0,g_sDeniedMsg);
                            llMessageLinked(LINK_SET,CMD_NOACCESS,sStr,kID);
                        }
                    }
                }
            }
        }else if(iNum==MENUNAME_REQUEST && sStr==g_sParentMenu){
            llMessageLinked(iSender, MENUNAME_RESPONSE, g_sParentMenu+"|"+g_sSubMenu, "");
        }else if(iNum==DIALOG_RESPONSE){
            integer iIndex = llListFindList(g_lMenuIDs,[kID]);
            if(~iIndex){
                key kAv = llList2Key(g_lMenuIDs,iIndex-1);
                string sMsg = llList2String(llParseString2List(sStr,["|"],[]),1);
                string sType = llList2String(g_lMenuIDs,iIndex+1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs,iIndex-1,iIndex-1+g_iMenuStride-1);
                if(sType=="main"){
                    if(sMsg==UPMENU) llMessageLinked(LINK_SET,iSender,"menu "+g_sParentMenu,kAv);
                    else if(sMsg=="▣ Notify") { g_iNotify=FALSE; LSDWrite("notify","0"); mainMenu(kAv,iSender); }
                    else if(sMsg=="☐ Notify") { g_iNotify=TRUE; LSDWrite("notify","1"); mainMenu(kAv,iSender); }
                    else if(sMsg=="♂ Only") { g_iAllowedGender=1; LSDWrite("allowed","0"); mainMenu(kAv,iSender); }
                    else if(sMsg=="♀ Only") { g_iAllowedGender=0; LSDWrite("allowed","1"); mainMenu(kAv,iSender); }
                    else if(sMsg=="♂♀ Both") { g_iAllowedGender=2; LSDWrite("allowed","2"); mainMenu(kAv,iSender); }
                    else if(sMsg=="Message") {
                        Dialog(kAv,"Enter deny message",[],[],0,iSender,"textbox");
                    }
                }else if(sType=="textbox"){
                    if(sMsg!=" ") { g_sDeniedMsg=sMsg; LSDWrite("message",sMsg); }
                    mainMenu(kAv,iSender);
                }
            }
        }else if(iNum==LM_SETTING_RESPONSE){
            list l=llParseString2List(sStr,["_","="],[]);
            if(llList2String(l,0)=="global" && llList2String(l,1)=="hide") g_iHideState=(integer)llList2String(l,2);
        }else if(iNum==CMD_PARTICLE){
            if(sStr=="unleash"){
                if(g_iRestoreHide){ HideCollar(); g_iRestoreHide=FALSE; }
            }else if(llSubStringIndex(sStr,"leash")==0){
                if(g_iHideState){ g_iRestoreHide=TRUE; ShowCollar(); }
            }
        }
    }
}
