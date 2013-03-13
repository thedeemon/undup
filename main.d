module main;
import std.stdio, scans, dfl.application, dfl.messagebox;

void main(string[] argv)
{
	//if (argv.length < 3) {
		//try	{
			Application.enableVisualStyles();
			Application.autoCollect = false;
			Application.run(new Scans());
		/*}
		catch(Throwable o) {
			msgBox(o.toString(), "Fatal Error", MsgBoxButtons.OK, MsgBoxIcon.ERROR);		
		}*/
	/*} else
	if (argv[1]=="show") showDump(argv[2]);
	else
	if (argv[1]=="join" && argv.length >= 5) joinDumps(argv[2], argv[3..$]); 
	else
	if (argv[1]=="search") searchDups(argv[2]);
	else
	if (argv[1]=="vsearch") vsearch(argv[2]);
	else 
	writeln("bad command");*/
}
