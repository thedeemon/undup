module main;
import fileops, std.stdio, visual, scans, dfl.application, dfl.messagebox;

void main(string[] argv)
{
	if (argv.length < 3) {
		//writeln("usage: undup {dump fname name} | {show fname} | {join target src1 src2 ...} | {search fname}");
		//return;
		try
		{
			Application.enableVisualStyles();
			Application.autoCollect = false;
			//@  Other application initialization code here.
			Application.run(new Scans());
		}
		catch(Throwable o)
		{
			msgBox(o.toString(), "Fatal Error", MsgBoxButtons.OK, MsgBoxIcon.ERROR);		
		}
	}
	if (argv[1]=="dump" && argv.length >= 4)
		makeDump(argv[2], argv[3]);
	else
	if (argv[1]=="show") showDump(argv[2]);
	else
	if (argv[1]=="join" && argv.length >= 5) joinDumps(argv[2], argv[3..$]); 
	else
	if (argv[1]=="search") searchDups(argv[2]);
	else
	if (argv[1]=="vsearch") vsearch(argv[2]);
	else 
	writeln("bad command");

}
