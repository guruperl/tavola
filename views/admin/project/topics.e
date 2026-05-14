[% INCLUDE start.e %]

<script>
function resize(id,event) {
    var area = document.getElementById(id);
    if(13==event.keyCode) { area.rows = area.value.split("\n").length;}
    if(8==event.keyCode || 46==event.keyCode) {  area.rows = area.value.split("\n").length;}
};
</script>

  <form action=project method=post><input type=hidden name=force value=1><input type=hidden name=action value=insert><div class='form_settings'>

[% IF topics AND topics.0 %]<h3>Current Projects</h3>
<table width=100%>
<tr>
<td><strong>Name</strong></td>
<td>Created</td>
<td> </td>
<td> </td>
<td> </td>
<td> </td>
</tr>[% FOREACH p IN topics %]
<tr>
<td>[% p.Project FILTER ucfirst %]</td>
<td>[% p.created %]</td>
<!-- td [% IF (p.dtime AND p.dtime<p.mtime) %] style="color: brown"[% END %] width=25%>[% p.dtime_str %]</td -->
<td><a href="project?action=edit&project=[% p.name FILTER lower %]">Edit</a></td>
<td><a href="project?action=delete&project=[% p.name FILTER lower %]"  onCLick="return confirm('This will delete the whole project. Are you sure?')">Delete</a></td>
<td><a download href="../xtar/project?action=topics&memberid=[% p.memberid %]&projectid=[% p.projectid %]&login=[% p.Project FILTER lower %]">download</a></td>
<td><a href="project?action=loginas&provider=db&login=[% p.Project FILTER lower %]">Account</a></td>
</tr>
[% END %]</table>
<p> &nbsp; </p>[% END %]

<p> &nbsp; </p>

<h6>Build New Project</h6>

<h3>System Parameters</h3>
<p>
<span>Project Name</span>:
</p>
<input type=text name=project size=20 />
<p> &nbsp; </p>
<p>
<span>Components</span> (e.g. <em>Product, Order, Sale</em>, separated by comma):
</p>
<input type=text name=c_string size=20 />
<p style="padding-top: 15px"><span>&nbsp;</span>
<input class="submit" type=submit value='Do It!' /></p></div>
</form>

[% INCLUDE end.e %]
