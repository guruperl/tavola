function addRow(id){
var root = document.getElementById(id);
var allRows = root.getElementsByTagName('tr');
var cRow = allRows[allRows.length-1].cloneNode(true);
var cInp = cRow.getElementsByTagName('input');
for(var i=0;i<cInp.length;i++){
  var inputname = cInp[i].getAttribute('name');
  var two = inputname.split("_");
  cInp[i].setAttribute('name', two[0]+'_'+(allRows.length+1));
}
var cSel = cRow.getElementsByTagName('textarea')[0];
if (cSel != undefined)
  cSel.setAttribute('name',cSel.getAttribute('name')+'_'+(allRows.length+1));
root.appendChild(cRow);
}
function delRow(id){
var root = document.getElementById(id);
root.deleteRow(root.rows.length-1);
}
