// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import "../player/qml/redesign"

TestCase {
    id: testCase
    name: "JuxtopposedFolderInfo"
    width:1280; height:800; visible:true; when:windowShown
    RedesignFolderInfo { id: dialog; parent:testCase }
    function details(extra) {
        return Object.assign({success:true,name:"Movies & Shows",location:"/media/Movies & Shows",
            files:12,folders:3,size:1048576,created:1700000000000,modified:1700001000000,writable:true},extra||{})
    }
    function init() {
        width=1280; height=800; dialog.scaleFactor=1; dialog.lightTheme=false; dialog.close()
        dialog.begin(1); tryCompare(dialog,"opened",true); dialog.load(1,details())
    }
    function cleanup() { dialog.close(); tryCompare(dialog,"visible",false) }
    function test_metadataAndPlainSelectableLocation() {
        compare(findChild(dialog,"folderInfoName").text,"Movies & Shows")
        const location=findChild(dialog,"folderInfoLocation")
        compare(location.text,"/media/Movies & Shows"); verify(location.readOnly); verify(location.selectByMouse)
        dialog.load(1,details({location:"/media/<b>literal</b>"}))
        compare(location.textFormat,TextEdit.PlainText)
        compare(dialog.size(0),"0 B"); verify(dialog.size(1048576).includes("MiB"))
        compare(dialog.date(null),"Unknown"); compare(dialog.date(undefined),"Unknown")
        verify(dialog.date(0)!=="Unknown")
    }
    function test_staleAndClosedResultsAreIgnored() {
        dialog.begin(2); dialog.load(1,details({name:"Old"}))
        verify(dialog.loading); compare(dialog.info.name,undefined)
        dialog.reject(); dialog.load(2,details()); compare(dialog.info.name,undefined)
        dialog.begin(3); dialog.load(3,details({name:"New"})); compare(dialog.info.name,"New")
    }
    function test_unavailableFolderShowsErrorAndLocation() {
        dialog.begin(2); dialog.load(2,{success:false,location:"/offline/Movies"})
        verify(!dialog.loading); verify(dialog.errorMessage.length>0)
        verify(findChild(dialog,"folderInfoError").visible)
        compare(findChild(dialog,"folderInfoLocation").text,"/offline/Movies")
        mouseClick(findChild(dialog,"folderInfoClose")); tryCompare(dialog,"visible",false)
    }
    function test_escapeAndHeaderCloseDuringLoad() {
        dialog.begin(2); keyClick(Qt.Key_Escape); tryCompare(dialog,"visible",false)
        dialog.begin(3); tryCompare(dialog,"opened",true)
        mouseClick(findChild(dialog,"folderInfoHeaderClose")); tryCompare(dialog,"visible",false)
    }
    function test_scaledAndSmallWindow_data() {
        return [{tag:"small",w:500,h:300,scale:1},{tag:"scaled",w:1280,h:800,scale:1.5},{tag:"light",w:1280,h:800,scale:1,light:true}]
    }
    function test_scaledAndSmallWindow(data) {
        width=data.w; height=data.h; dialog.scaleFactor=data.scale; dialog.lightTheme=!!data.light
        dialog.load(1,details({location:"/media/"+"long folder name/".repeat(30),writable:false}))
        wait(50); verify(dialog.x>=0 && dialog.y>=0)
        verify(dialog.x+dialog.width<=width && dialog.y+dialog.height<=height)
        for(const name of ["folderInfoHeaderClose","folderInfoClose"]) {
            const button=findChild(dialog,name), point=button.mapToItem(testCase,0,0)
            verify(point.x>=0 && point.y>=0,name)
            verify(point.x+button.width<=width && point.y+button.height<=height,name)
        }
        dialog.begin(2); dialog.load(2,{success:false,location:"/offline"}); wait(20)
        const error=findChild(dialog,"folderInfoError"), close=findChild(dialog,"folderInfoClose")
        verify(error.mapToItem(testCase,0,0).y+error.height<=close.mapToItem(testCase,0,0).y)
    }
}
