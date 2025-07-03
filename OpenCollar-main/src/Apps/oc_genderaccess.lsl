#pragma strict
// Gender Access Plugin for OpenCollar
// Controls access to collar menu based on toucher gender and provides notifications.

string g_sParentMenu = "Apps";
string g_sSubMenu = "GenderAccess";
string g_sSettingToken = "genderaccess_";
string g_sScriptVersion = "1.0";

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
integer MENUNAME_REMOVE  = 3003;
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT  = -9002;
string UPMENU = "BACK";

key g_kWearer;

integer g_iNotify = TRUE;      // notify wearer of attempts
integer g_iAllowed = 0;        // 0 both, 1 males only, 2 females only
string  g_sCustom = "";        // custom denial message

integer g_iPublic = FALSE;     // collar public mode
integer g_iHide   = FALSE;     // current visibility
integer g_iPrevHide = FALSE;   // previous hide before leash
integer g_iShownDueToLeash = FALSE;

list g_lMenuIDs;
integer g_iMenuStride = 3;

string Checkbox(integer v,string l){ return llList2String(["□","▣"],v)+" "+l; }
string NameURI(key k){ return "secondlife:///app/agent/"+(string)k+"/about"; }

string buttonGender(){
    if(g_iAllowed==1) return "Males";
    if(g_iAllowed==2) return "Females";
    return "Both";
}

Dialog(key kAv,string p,list b,list u,integer page,integer auth,string m){
    key id = llGenerateKey();
    llMessageLinked(LINK_THIS,DIALOG,(string)kAv+"|"+p+"|"+(string)page+"|"+llDumpList2String(b,"`")+"|"+llDumpList2String(u,"`")+"|"+(string)auth,id);
    integer i = llListFindList(g_lMenuIDs,[kAv]);
    if(~i) g_lMenuIDs = llListReplaceList(g_lMenuIDs,[kAv,id,m],i,i+g_iMenuStride-1);
    else g_lMenuIDs += [kAv,id,m];
}

save(){
    llMessageLinked(LINK_THIS,LM_SETTING_SAVE,g_sSettingToken+"notify="+(string)g_iNotify,"");
    llMessageLinked(LINK_THIS,LM_SETTING_SAVE,g_sSettingToken+"gender="+(string)g_iAllowed,"");
    llMessageLinked(LINK_THIS,LM_SETTING_SAVE,g_sSettingToken+"message="+g_sCustom,"");
}

mainMenu(key kAv,integer auth){
    string prompt="Gender Access Control\n";
    list b=[buttonGender(),Checkbox(g_iNotify,"Notify"),"Message","Remove"];
    Dialog(kAv,prompt,b,[UPMENU],0,auth,"Main");
}

string DetectGender(key id){
    list at=llGetAttachedList(id);
    integer i; integer e=llGetListLength(at);
    while(i<e){
        string n=llToLower(llList2String(llGetObjectDetails(llList2Key(at,i),[OBJECT_NAME]),0));
        if(~llSubStringIndex(n,"vagina")||~llSubStringIndex(n,"pussy")||~llSubStringIndex(n,"cunt")||~llSubStringIndex(n,"breast")||~llSubStringIndex(n,"boob")) return "Female";
        if(~llSubStringIndex(n,"penis")||~llSubStringIndex(n,"cock")||~llSubStringIndex(n,"phallus")||~llSubStringIndex(n,"dick")) return "Male";
        ++i;
    }
    return "Unknown";
}

processAccess(key av,integer auth,key menuID){
    string gender=DetectGender(av);
    if(g_iNotify) llMessageLinked(LINK_THIS,NOTIFY,"0"+NameURI(av)+" ("+gender+") attempted menu access.",g_kWearer);
    integer block=FALSE;
    if(g_iPublic && auth==CMD_EVERYONE){
        if(g_iAllowed==1 && gender!="Male") block=TRUE;
        else if(g_iAllowed==2 && gender!="Female") block=TRUE;
    }
    if(block){
        if(g_sCustom!="") llRegionSayTo(av,0,g_sCustom);
        llMessageLinked(LINK_THIS,DIALOG_TIMEOUT,"",menuID);
    }
}

state default{
    state_entry(){
        g_kWearer=llGetOwner();
        llMessageLinked(LINK_THIS,LM_SETTING_REQUEST,g_sSettingToken+"notify","");
        llMessageLinked(LINK_THIS,LM_SETTING_REQUEST,g_sSettingToken+"gender","");
        llMessageLinked(LINK_THIS,LM_SETTING_REQUEST,g_sSettingToken+"message","");
        llMessageLinked(LINK_THIS,LM_SETTING_REQUEST,"auth_public","");
        llMessageLinked(LINK_THIS,LM_SETTING_REQUEST,"global_hide","");
    }
    on_rez(integer p){ llResetScript(); }
    link_message(integer s,integer num,string str,key id){
        if(num==MENUNAME_REQUEST && str==g_sParentMenu)
            llMessageLinked(s,MENUNAME_RESPONSE,g_sParentMenu+"|"+g_sSubMenu,"");
        else if(num>=CMD_OWNER && num<=CMD_EVERYONE){
            list l=llParseString2List(str,[" "],[]);
            if(llToLower(llList2String(l,0))=="menu" && llList2String(l,1)==g_sSubMenu) mainMenu(id,num);
        } else if(num==DIALOG){
            list p=llParseStringKeepNulls(str,["|"],[]);
            key rcpt=llGetOwnerKey((key)llList2String(p,0));
            integer auth=(integer)llList2String(p,5);
            processAccess(rcpt,auth,id);
        } else if(num==DIALOG_RESPONSE){
            integer i=llListFindList(g_lMenuIDs,[id]);
            if(~i){
                key av=llList2Key(g_lMenuIDs,i);
                string menu=llList2String(g_lMenuIDs,i+2);
                g_lMenuIDs=llDeleteSubList(g_lMenuIDs,i,i+2);
                list l=llParseString2List(str,["|"],[]); string msg=llList2String(l,1); integer auth=llList2Integer(l,3);
                if(menu=="Main"){ if(msg==UPMENU) llMessageLinked(LINK_THIS,auth,"menu "+g_sParentMenu,av); else if(msg==buttonGender()){ g_iAllowed=(g_iAllowed+1)%3; save(); mainMenu(av,auth);} else if(msg==Checkbox(g_iNotify,"Notify")){ g_iNotify=!g_iNotify; save(); mainMenu(av,auth);} else if(msg=="Message"){ Dialog(av,"Enter denial message (blank to disable):",[" "],[UPMENU],0,auth,"Msg"); } else if(msg=="Remove"){ Dialog(av,"Remove Gender Access plugin?",["Yes","No"],[],0,auth,"Remove"); } }
                else if(menu=="Msg"){ msg=llStringTrim(msg,STRING_TRIM); g_sCustom=msg; save(); mainMenu(av,auth); }
                else if(menu=="Remove"){ if(msg=="Yes"){ llMessageLinked(LINK_ROOT,MENUNAME_REMOVE,g_sParentMenu+"|"+g_sSubMenu,""); llMessageLinked(LINK_THIS,LM_SETTING_DELETE,g_sSettingToken+"notify",""); llMessageLinked(LINK_THIS,LM_SETTING_DELETE,g_sSettingToken+"gender",""); llMessageLinked(LINK_THIS,LM_SETTING_DELETE,g_sSettingToken+"message",""); if (llGetInventoryType(llGetScriptName())==INVENTORY_SCRIPT) llRemoveInventory(llGetScriptName()); } else mainMenu(av,auth); }
            }
        } else if(num==LM_SETTING_RESPONSE){
            list p=llParseString2List(str,["="],[]); string t=llList2String(p,0); string v=llList2String(p,1);
            if(t==g_sSettingToken+"notify") g_iNotify=(integer)v;
            else if(t==g_sSettingToken+"gender") g_iAllowed=(integer)v;
            else if(t==g_sSettingToken+"message") g_sCustom=v;
            else if(t=="auth_public") g_iPublic=(integer)v;
            else if(t=="global_hide") g_iHide=(integer)v;
        } else if(num==LM_SETTING_SAVE){
            integer i=llSubStringIndex(str,"="); string t=llGetSubString(str,0,i-1); string v=llGetSubString(str,i+1,-1);
            if(t=="auth_public") g_iPublic=(integer)v;
            else if(t=="global_hide") g_iHide=(integer)v;
            else if(t=="leash_leashedto" && v!=""){ g_iPrevHide=g_iHide; if(g_iHide){ llMessageLinked(LINK_THIS,CMD_OWNER,"show",g_kWearer); g_iShownDueToLeash=TRUE; } }
        } else if(num==LM_SETTING_DELETE){
            if(str=="leash_leashedto"){ if(g_iShownDueToLeash && g_iPrevHide) llMessageLinked(LINK_THIS,CMD_OWNER,"hide",g_kWearer); g_iShownDueToLeash=FALSE; }
        } else if(num==REBOOT && str=="reboot") llResetScript();
    }
}
