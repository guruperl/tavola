[% INCLUDE start.e %]

<h3>[% errorstr %]</h3>

<FORM METHOD="POST" ACTION="[% script_name %]">
<INPUT TYPE="HIDDEN" NAME="[% CREDENTIAL_0 %]" VALUE="[% go_uri %]" />
<table>
<tr><td>Login: &nbsp; </td>
<td><INPUT TYPE="TEXT"     NAME="[% CREDENTIAL_1 %]" size=20 /></td></tr>
<tr><td>Passowrd: &nbsp; </td>
<td><INPUT TYPE="PASSWORD" NAME="[% CREDENTIAL_2 %]" size=20 /></td></tr>
<tr><td colspan=2> &nbsp; </td></tr>
<tr><td> </td>
<td><INPUT TYPE="SUBMIT" VALUE=" Log In " /></td></tr>
</table>
</FORM>

[% INCLUDE end.e %]
