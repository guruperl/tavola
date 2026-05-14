[% INCLUDE start.e %]

<form action=component method=post><input type=hidden name=project value="[% project %]" /><input type=hidden name=force value=1 /><input type=hidden name=action value=insert /><div class='form_settings'>
 
[% IF topics AND topics.0 %]<h3>Current Components</h3>
<table width=600><tr><td><strong>Name</strong></td><td>Last Modified</td><td> </td><td> </td></tr>[% FOREACH c IN topics %]
<tr><td width=30%>[% c.name FILTER ucfirst %]</td>
<td width=40%>[% c.mtime %]</td>
<td width=15%><a href="component?action=edit&project=[% project FILTER lower %]&c=[% c.name FILTER lower %]">Edit</a></td>
<td width=15%><a href="component?action=delete&project=[% project FILTER lower %]&c=[% c.name FILTER lower %]" onCLick="return confirm('Are you sure you want to delete this component?')">Delete</a></td>
</tr>
[% END %]</table>
<p> &nbsp; </p>[% END %]

<h3>Build New Component</h3>
<p>
<span>Component</span>: usually a table name e.g. <em>Poll</em>.
</p>
<p> &nbsp; </p>
<table border=0 cellspacing=10 cellpadding=10>
<tr><td>Component</td><td><input class="flexible" type=text name=c /></td></tr>
<tr><td valign=top>Create Statement</td><td><textarea class="flexible textarea" name=statement cols=85 rows=10></textarea></td></tr>
</table>

<p> &nbsp; </p>
<h3>Role Privileges</h3>
<p>
Defining exeutable privileges for public and protected roles on standard actions. Administrative roles can execute any action.
</p>
<p> &nbsp; </p>
<table border=0 cellspacing=10 cellpadding=10>
<tr><th>Action</th><th>[% item.general.pubrole %]</th><th>[% FOREACH pair IN item.roles %][% UNLESS pair.value.is_admin %]<th>[% pair.key %]</th>[% END %][% END %]</tr>
[% FOREACH act IN actions %]<tr>
<td>[% act %]</td>
<td><input type=checkbox name=[% act %] value=[% item.general.pubrole %] /></td>[% FOREACH pair IN item.roles %][% UNLESS pair.value.is_admin %]
<td><input type=checkbox name=[% act %] value=[% pair.key %] /></td>
[% END %][% END %]</tr>
[% END %]</table>

<p style="padding-top: 15px"><span>&nbsp;</span><input class="submit" type=submit value="Do It!" /></p>
</div></form>

[% INCLUDE end.e %]
