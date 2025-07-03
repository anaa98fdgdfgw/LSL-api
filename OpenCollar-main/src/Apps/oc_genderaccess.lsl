/*
Menu Access Guard plugin for OpenCollar
--------------------------------------
This example plugin notifies the wearer when others attempt to access
menus and optionally restricts public menu access based on a simple
gender guess. It also supports an optional message sent to blocked
users and can toggle collar visibility when leashed.

This script is intentionally simplified for demonstration purposes.
*/

string g_sParentMenu = "Apps";
string g_sSubMenu   = "AccessGuard";

integer CMD_OWNER   = 500;
integer CMD_TRUSTED = 501;
integer CMD_GROUP   = 502;
integer CMD_WEARER  = 503;
integer CMD_EVERYONE= 504;

integer NOTIFY = 1002;
integer REBOOT = -1000;
integer LM_SETTING_SAVE = 2000;
integer LM_SETTING_REQUEST = 2001;
integer LM_SETTING_RESPONSE = 2002;
integer LM_SETTING_DELETE = 2003;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

string UPMENU = "BACK";

integer LEASH_START_MOVEMENT = 6200;
integer LEASH_END_MOVEMENT   = 6201;

// configuration
integer g_iNotify = TRUE;       // send wearer message on menu access
integer g_iGenderMode = 0;      // 0=Both,1=Males only,2=Females only
string  g_sBlockMsg = "";       // message sent when gender blocked
integer g_iVisibleOnLeash = TRUE; // hide/unhide on leash
integer g_iHiddenBeforeLeash = FALSE;
list g_lTempBlocks = []; // avatars auto blocked for gender mismatch

list g_lMaleBodies = [
    "Gianni",
    "Belleza Jake"
];
list g_lFemaleBodies = [
    "Maitreya",
    "Legacy"
];

key g_kWearer;
list g_lMenuIDs; // [avatar, dialogID, menuName]
integer g_iMenuStride = 3;

// remove all temporarily blocked avatars
ClearTempBlocks()
{
    integer i;
    for(i=0;i<llGetListLength(g_lTempBlocks);++i)
        llMessageLinked(LINK_SET,CMD_OWNER,"rem block "+(string)llList2Key(g_lTempBlocks,i),g_kWearer);
    if(llGetListLength(g_lTempBlocks)>0)
        llMessageLinked(LINK_SET,NOTIFY,"0All temporary bans cleared",g_kWearer);
    g_lTempBlocks=[];
}

string GenderString(integer mode)
{
    if(mode==1) return "Males";
    if(mode==2) return "Females";
    return "Both";
}

string GuessGender(key id)
{
    list atts = llGetAttachedList(id);
    integer i;
    for(i=0; i<llGetListLength(atts); ++i)
    {
        string nm = llToLower(llKey2Name(llList2Key(atts,i)));
        integer j;
        for(j=0; j<llGetListLength(g_lMaleBodies); ++j)
            if(~llSubStringIndex(nm,llToLower(llList2String(g_lMaleBodies,j))))
                return "male";
        for(j=0; j<llGetListLength(g_lFemaleBodies); ++j)
            if(~llSubStringIndex(nm,llToLower(llList2String(g_lFemaleBodies,j))))
                return "female";
    }
    string name = llToLower(llKey2Name(id));
    if(~llSubStringIndex(name,"mr ") || ~llSubStringIndex(name,"sir")) return "male";
    if(~llSubStringIndex(name,"miss") || ~llSubStringIndex(name,"lady")) return "female";
    return "unknown";
}

integer GenderAllowed(string gender)
{
    if(g_iGenderMode==0) return TRUE;
    if(gender=="male" && g_iGenderMode==1) return TRUE;
    if(gender=="female" && g_iGenderMode==2) return TRUE;
    return FALSE;
}

integer IsPrivileged(integer auth)
{
    return (auth==CMD_OWNER || auth==CMD_TRUSTED);
}

Dialog(key kID,string prompt,list buttons,list util,int page,integer auth,string name)
{
    key dlg=llGenerateKey();
    llMessageLinked(LINK_SET,DIALOG,(string)kID+"|"+prompt+"|"+(string)page+"|"+llDumpList2String(buttons,"`")+"|"+llDumpList2String(util,"`")+"|"+(string)auth,dlg);
    integer idx=llListFindList(g_lMenuIDs,[kID]);
    if(~idx) g_lMenuIDs=llListReplaceList(g_lMenuIDs,[kID,dlg,name],idx,idx+g_iMenuStride-1);
    else g_lMenuIDs+=[kID,dlg,name];
}

MainMenu(key kID,integer auth)
{
    list btn=[Checkbox(g_iNotify,"Notify"),
              "Gender: "+GenderString(g_iGenderMode),
              "Male List","Female List",
              "Set Msg",
              "Deban All",
              Checkbox(g_iVisibleOnLeash,"LeashVis")];
    Dialog(kID,"\n[Access Guard]",btn,[UPMENU],0,auth,"main");
}

GenderMenu(key kID,integer auth)
{
    Dialog(kID,"\nChoose allowed gender",["Both","Males","Females"],[UPMENU],0,auth,"gender");
}

EditListMenu(key kID,integer auth,string type)
{
    list data = (type=="male")?g_lMaleBodies:g_lFemaleBodies;
    string title = "\\nEdit "+type+" bodies";
    list btn = ["Add","Remove","Clear"];
    Dialog(kID,title,btn,[UPMENU],0,auth,"edit"+type);
}

RemoveListMenu(key kID,integer auth,string type)
{
    list data = (type=="male")?g_lMaleBodies:g_lFemaleBodies;
    list btn = llList2List(data,0,8);
    if(llGetListLength(btn)==0) btn=["(None)"]; // show placeholder
    Dialog(kID,"\\nTap item to remove",btn,[UPMENU],0,auth,"rem"+type);
}

string Checkbox(integer v,string label){ return llList2String(["□","▣"],v>0)+" "+label; }

HandleMenuAccess(integer auth,key id)
{
    string gender=GuessGender(id);
    if(g_iNotify)
        llMessageLinked(LINK_SET,NOTIFY,"0Attempted menu access by "+llKey2Name(id)+" ("+gender+")",g_kWearer);
    if(!IsPrivileged(auth) && !GenderAllowed(gender))
    {
        if(g_sBlockMsg!="") llInstantMessage(id,g_sBlockMsg);
        if(llListFindList(g_lTempBlocks,[id])==-1)
        {
            g_lTempBlocks+=id;
            llMessageLinked(LINK_SET,CMD_OWNER,"add block "+(string)id,g_kWearer);
        }
        return; // block
    }
    llMessageLinked(LINK_SET,auth,"menu",id); // forward
}

state default
{
    state_entry()
    {
        g_kWearer=llGetOwner();
        llMessageLinked(LINK_SET,LM_SETTING_REQUEST,"accessguard_notify","");
        llMessageLinked(LINK_SET,LM_SETTING_REQUEST,"accessguard_gender","");
        llMessageLinked(LINK_SET,LM_SETTING_REQUEST,"accessguard_blockmsg","");
        llMessageLinked(LINK_SET,LM_SETTING_REQUEST,"accessguard_visible","");
        llMessageLinked(LINK_SET,LM_SETTING_REQUEST,"accessguard_malelist","");
        llMessageLinked(LINK_SET,LM_SETTING_REQUEST,"accessguard_femlist","");
    }
    on_rez(integer p){ llResetScript(); }
    link_message(integer s,integer n,string m,key id)
    {
        if(n>=CMD_OWNER && n<=CMD_EVERYONE)
        {
            if(m=="menu" || llSubStringIndex(m,"menu ")==0)
                HandleMenuAccess(n,id);
        }
        else if(n==MENUNAME_REQUEST && m==g_sParentMenu)
            llMessageLinked(s,MENUNAME_RESPONSE,g_sParentMenu+"|"+g_sSubMenu,"");
        else if(n==DIALOG_RESPONSE)
        {
            integer idx=llListFindList(g_lMenuIDs,[id]);
            if(~idx)
            {
                string name=llList2String(g_lMenuIDs,idx+1);
                g_lMenuIDs=llDeleteSubList(g_lMenuIDs,idx-1,idx-2+g_iMenuStride);
                list par=llParseString2List(m,["|"],[]);
                key av=llList2Key(par,0);
                string msg=llList2String(par,1);
                integer auth=llList2Integer(par,3);
                if(name=="main")
                {
                    if(msg==UPMENU) llMessageLinked(LINK_SET,auth,"menu "+g_sParentMenu,av);
                    else if(msg=="Gender: "+GenderString(g_iGenderMode)) GenderMenu(av,auth);
                    else if(msg=="Male List") EditListMenu(av,auth,"male");
                    else if(msg=="Female List") EditListMenu(av,auth,"female");
                    else if(msg=="Set Msg") Dialog(av,"\nEnter block message",[],[],0,auth,"msgbox");
                    else if(msg=="Deban All")
                    {
                        ClearTempBlocks();
                        MainMenu(av,auth);
                    }
                    else if(msg==Checkbox(g_iNotify,"Notify"))
                    {
                        g_iNotify=!g_iNotify;
                        llMessageLinked(LINK_SET,LM_SETTING_SAVE,"accessguard_notify="+(string)g_iNotify,"");
                        MainMenu(av,auth);
                    }
                    else if(msg==Checkbox(g_iVisibleOnLeash,"LeashVis"))
                    {
                        g_iVisibleOnLeash=!g_iVisibleOnLeash;
                        llMessageLinked(LINK_SET,LM_SETTING_SAVE,"accessguard_visible="+(string)g_iVisibleOnLeash,"");
                        MainMenu(av,auth);
                    }
                }
                else if(name=="gender")
                {
                    if(msg==UPMENU) MainMenu(av,auth);
                    else
                    {
                        if(msg=="Both") g_iGenderMode=0;
                        else if(msg=="Males") g_iGenderMode=1;
                        else if(msg=="Females") g_iGenderMode=2;
                        llMessageLinked(LINK_SET,LM_SETTING_SAVE,"accessguard_gender="+(string)g_iGenderMode,"");
                        ClearTempBlocks();
                        MainMenu(av,auth);
                    }
                }
                else if(name=="msgbox")
                {
                    if(msg!="")
                    {
                        g_sBlockMsg=msg;
                        llMessageLinked(LINK_SET,LM_SETTING_SAVE,"accessguard_blockmsg="+llEscapeURL(g_sBlockMsg),"");
                    }
                    MainMenu(av,auth);
                }
                else if(name=="editmale")
                {
                    if(msg==UPMENU) MainMenu(av,auth);
                    else if(msg=="Add") Dialog(av,"\\nEnter body name",[],[],0,auth,"addmale");
                    else if(msg=="Remove") RemoveListMenu(av,auth,"male");
                    else if(msg=="Clear")
                    {
                        g_lMaleBodies=[];
                        llMessageLinked(LINK_SET,LM_SETTING_SAVE,"accessguard_malelist=","");
                        EditListMenu(av,auth,"male");
                    }
                }
                else if(name=="editfemale")
                {
                    if(msg==UPMENU) MainMenu(av,auth);
                    else if(msg=="Add") Dialog(av,"\\nEnter body name",[],[],0,auth,"addfemale");
                    else if(msg=="Remove") RemoveListMenu(av,auth,"female");
                    else if(msg=="Clear")
                    {
                        g_lFemaleBodies=[];
                        llMessageLinked(LINK_SET,LM_SETTING_SAVE,"accessguard_femlist=","");
                        EditListMenu(av,auth,"female");
                    }
                }
                else if(name=="addmale")
                {
                    if(msg!="")
                        g_lMaleBodies+=msg;
                    llMessageLinked(LINK_SET,LM_SETTING_SAVE,"accessguard_malelist="+llEscapeURL(llList2CSV(g_lMaleBodies)),"");
                    EditListMenu(av,auth,"male");
                }
                else if(name=="addfemale")
                {
                    if(msg!="")
                        g_lFemaleBodies+=msg;
                    llMessageLinked(LINK_SET,LM_SETTING_SAVE,"accessguard_femlist="+llEscapeURL(llList2CSV(g_lFemaleBodies)),"");
                    EditListMenu(av,auth,"female");
                }
                else if(name=="remmale")
                {
                    integer idx=llListFindList(g_lMaleBodies,[msg]);
                    if(~idx) g_lMaleBodies=llDeleteSubList(g_lMaleBodies,idx,idx);
                    llMessageLinked(LINK_SET,LM_SETTING_SAVE,"accessguard_malelist="+llEscapeURL(llList2CSV(g_lMaleBodies)),"");
                    EditListMenu(av,auth,"male");
                }
                else if(name=="remfemale")
                {
                    integer idx=llListFindList(g_lFemaleBodies,[msg]);
                    if(~idx) g_lFemaleBodies=llDeleteSubList(g_lFemaleBodies,idx,idx);
                    llMessageLinked(LINK_SET,LM_SETTING_SAVE,"accessguard_femlist="+llEscapeURL(llList2CSV(g_lFemaleBodies)),"");
                    EditListMenu(av,auth,"female");
                }
            }
        }
        else if(n==LM_SETTING_RESPONSE)
        {
            list l=llParseString2List(m,["="],[]);
            if(llList2String(l,0)=="accessguard_notify") g_iNotify=(integer)llList2String(l,1);
            else if(llList2String(l,0)=="accessguard_gender") g_iGenderMode=(integer)llList2String(l,1);
            else if(llList2String(l,0)=="accessguard_blockmsg") g_sBlockMsg=llUnescapeURL(llList2String(l,1));
            else if(llList2String(l,0)=="accessguard_visible") g_iVisibleOnLeash=(integer)llList2String(l,1);
            else if(llList2String(l,0)=="accessguard_malelist")
                g_lMaleBodies=llCSV2List(llUnescapeURL(llList2String(l,1)));
            else if(llList2String(l,0)=="accessguard_femlist")
                g_lFemaleBodies=llCSV2List(llUnescapeURL(llList2String(l,1)));
        }
        else if(n==LEASH_START_MOVEMENT)
        {
            if(g_iVisibleOnLeash)
            {
                g_iHiddenBeforeLeash=!llGetLinkAlpha(LINK_ROOT,ALL_SIDES);
                if(g_iHiddenBeforeLeash)
                    llMessageLinked(LINK_THIS,CMD_OWNER,"show",g_kWearer);
            }
        }
        else if(n==LEASH_END_MOVEMENT)
        {
            if(g_iVisibleOnLeash && g_iHiddenBeforeLeash)
                llMessageLinked(LINK_THIS,CMD_OWNER,"hide",g_kWearer);
        }
        else if(n==REBOOT) llResetScript();
    }
    touch_start(integer t)
    {
        key id=llDetectedKey(0);
        HandleMenuAccess(CMD_EVERYONE,id);
    }
}
