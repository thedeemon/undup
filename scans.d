module scans;
import dfl.all, newscan, fileops, visual, resizer, std.file, std.stdio, std.conv, std.datetime, std.algorithm, 
	std.range, std.array, std.string;

class Scans: dfl.form.Form
{
	// Do not modify or move this block of variables.
	//~Entice Designer variables begin here.
	dfl.listview.ListView lvScans;
	dfl.button.Button btnNew;
	dfl.button.Button btnShow;
	dfl.button.Button btnRemove;
	dfl.button.Button btnAbout;
	dfl.label.Label label1;
	//~Entice Designer variables end here.
	Resizer resizer;
	
	this()
	{
		initializeScans();		
		//@  Other Scans initialization code here.		
	}
	
	
	private void initializeScans()
	{
		// Do not manually modify this function.
		//~Entice Designer 0.8.5.02 code begins here.
		//~DFL Form
		text = "Scans";
		clientSize = dfl.all.Size(784, 618);
		//~DFL dfl.listview.ListView=lvScans
		lvScans = new dfl.listview.ListView();
		lvScans.name = "lvScans";
		lvScans.allowColumnReorder = true;
		lvScans.checkBoxes = false;
		lvScans.fullRowSelect = true;
		lvScans.hideSelection = false;
		lvScans.labelWrap = false;
		lvScans.view = dfl.all.View.DETAILS;
		lvScans.bounds = dfl.all.Rect(8, 40, 768, 520);
		lvScans.parent = this;
		//~DFL dfl.button.Button=btnNew
		btnNew = new dfl.button.Button();
		btnNew.name = "btnNew";
		btnNew.text = "New scan";
		btnNew.bounds = dfl.all.Rect(8, 8, 104, 24);
		btnNew.parent = this;
		//~DFL dfl.button.Button=btnShow
		btnShow = new dfl.button.Button();
		btnShow.name = "btnShow";
		btnShow.text = "Show";
		btnShow.bounds = dfl.all.Rect(152, 8, 104, 24);
		btnShow.parent = this;
		//~DFL dfl.button.Button=btnRemove
		btnRemove = new dfl.button.Button();
		btnRemove.name = "btnRemove";
		btnRemove.text = "Remove";
		btnRemove.bounds = dfl.all.Rect(544, 8, 104, 24);
		btnRemove.parent = this;
		//~DFL dfl.button.Button=btnAbout
		btnAbout = new dfl.button.Button();
		btnAbout.name = "btnAbout";
		btnAbout.text = "?";
		btnAbout.bounds = dfl.all.Rect(752, 8, 24, 24);
		btnAbout.parent = this;
		//~DFL dfl.label.Label=label1
		label1 = new dfl.label.Label();
		label1.name = "label1";
		label1.text = "Scan one or more drives with 'New scan', then select the ones you want to see and compare using Ctrl-Click and press 'Show'. ";
		label1.bounds = dfl.all.Rect(8, 568, 768, 48);
		label1.parent = this;
		//~Entice Designer 0.8.5.02 code ends here.

		auto colnames = ["Name", "Path", "Label", "Size", "Time"];
		auto colwidths = [210, 220, 120, 60, 140];
		foreach(i; 0..colnames.length) {
			auto col = new ColumnHeader(colnames[i]);
			col.width = colwidths[i];
			lvScans.columns.add(col);
		}

		btnNew.click ~= &OnNewScan;
		btnShow.click ~= &OnShowScans;
		btnRemove.click ~= &OnRemove;
		
		this.minimumSize = Size(500, 200);

		resizer = new Resizer(this);
		resizer.let(lvScans, XCoord.resizes, YCoord.resizes);
		resizer.let(label1,  XCoord.resizes, YCoord.moves);
		resizer.let(btnRemove, XCoord.scalesPos, YCoord.stays);
		resizer.let(btnAbout, XCoord.moves, YCoord.stays);
		resizer.prepare();

		FillTable();
	}

	override void onResize(EventArgs ea)
	{
		resizer.go();
	}

	void OnNewScan(Control, EventArgs)
	{
		auto frm = new NewScan();
		frm.showDialog(this);
		lvScans.clear();
		FillTable();
	}

	void FillTable()
	{
		auto mydir = GetMyDir();
		foreach(string fname; dirEntries(mydir, "*.dmp", SpanMode.shallow)) {
			DumpHeader hdr;
			if (readHeader(fname, hdr)) {
				auto tm = (cast(DateTime) SysTime(hdr.time)).toSimpleString();
				auto item = lvScans.addRow([hdr.name, hdr.path, hdr.volume, hdr.volumeSize.to!string ~ " GB", tm]);
				item.tag = new Str(fname);
			}
		}
	}

	void OnShowScans(Control, EventArgs)
	{
		auto sel = lvScans.selectedItems;
		if (sel.length < 1) return;
		auto fnames = iota(0, sel.length).map!(i => (cast(Str) sel[i].tag).s).array;
		Show(fnames);
	}

	void OnRemove(Control, EventArgs)
	{
		auto sel = lvScans.selectedItems;
		if (sel.length < 1) return;
		auto sure = msgBox(format("Delete %s selected scans?", sel.length), "Remove scans?", MsgBoxButtons.YES_NO, MsgBoxIcon.QUESTION);		
		if (sure==DialogResult.YES) {
			foreach(i; 0..sel.length)
				remove((cast(Str) sel[i].tag).s);
			lvScans.clear();
			FillTable();
		}
	}

	void Show(string[] fnames)
	in 
	{ assert(fnames.length > 0); }
	body 
	{
		writeln("reading ");
		string[] names = fnames.map!getScanName.array;
		DirInfo[] dirs = useIndex(joinDumps(fnames));
		auto frm = new Visual(dirs, names);
		frm.showDialog(this);
	}

	class Str {
		string s;
		this(string str) { s = str; }
	}
}

string getScanName(string fname)
{
	DumpHeader hdr;
	if (readHeader(fname, hdr))
		return hdr.name;
	return "-";
}


