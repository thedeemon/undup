module visual;
import dfl.all, rel, fileops, messages, box, details, legend, taskbar, std.range, std.algorithm, 
	std.stdio, std.math, std.conv,	std.c.windows.windows, dfl.internal.winapi, std.string, 
	std.concurrency, std.typecons, core.time, core.memory;

class MyPictureBox : PictureBox {
	this() 
	{
		super();
		setStyle(ControlStyles.OPAQUE, true);
	}
}

int relColor(Rel r)
{
	final switch(r) {
		case Rel.Unknown:   return 0x010101;
		case Rel.ImNewer:   return 0x000100;
		case Rel.ImOlder:   return 0x010000;
		case Rel.Same:      return 0x010100;
		case Rel.Different: return 0x000000;
	}
}

class Coloring : IAsker {
	SimilarBoxes[int] simboxes;
	SimilarBoxes[string] fsimboxes;
	SimilarBoxes sb;

	this(SimilarBoxes[int] sbx, SimilarBoxes[string] fsbx) {
		simboxes = sbx;
		fsimboxes = fsbx;
	}
	this() {}

	void ImInt(int id) { if (id in simboxes) sb = simboxes[id]; }
	void ImString(string name) 
	{
		auto p = name in fsimboxes;
		if (p !is null) sb = *p;
	}
}

class Visual : dfl.form.Form
{
	Box[] top;
	DirInfo[] dirs;
	MyPictureBox picBox;
	dfl.label.Label lblFile, lblStatus;
	dfl.button.Button btnSearch, btnCancel, btnHelp;
	dfl.progressbar.ProgressBar progressBar;

	Rect[] volumeRects;
	Box[] pathToCurr;
	Coloring coloring;
	Box[] boxPixMap;
	int W,H;
	SimilarBoxes curSimBoxes;
	Box lastHoveredBox;
	Timer timer; // for receiving messages
	Font font;
	int errors;
	TaskBarProgress taskbarProgress;
	Tid mytid;

	this(DirInfo[] _dirs, string[] names) {
		W = 1040; H = 670;
		dirs = _dirs;
		version (verbose) writeln("making box tree");
		top = dirs.filter!(di => di.parent is null).map!(boxOfDir).array;
		coloring = new Coloring();
		errors = 0;
		initializeVisual(names);
	}

	void initializeVisual(string[] names)
	{
		text = "Undup: " ~ names.joiner(", ").array.to!string;
		clientSize = Size(1040, 730);

		picBox = new MyPictureBox();
		picBox.name = "picBox";
		picBox.sizeMode = PictureBoxSizeMode.NORMAL;
		picBox.bounds = Rect(0, 24, W, H);
		picBox.parent = this;

		lblFile = new dfl.label.Label();
		lblFile.name = "lblFile";
		lblFile.text = "---";
		lblFile.textAlign = ContentAlignment.MIDDLE_LEFT;
		lblFile.bounds = Rect(0, H+24, W-40, 24);
		lblFile.parent = this;

		lblStatus = new dfl.label.Label();
		lblStatus.name = "lblStatus";
		lblStatus.bounds = Rect(0, 0, 384, 24);
		lblStatus.parent = this;

		btnSearch = new dfl.button.Button();
		btnSearch.name = "btnSearch";
		btnSearch.text = "Search";
		btnSearch.bounds = Rect(392, 0, 72, 24);
		btnSearch.parent = this;

		btnCancel = new dfl.button.Button();
		btnCancel.name = "btnCancel";
		btnCancel.text = "Cancel";
		btnCancel.bounds = Rect(704, 0, 56, 24);
		btnCancel.parent = this;
		btnCancel.visible = false;

		progressBar = new dfl.progressbar.ProgressBar();
		progressBar.name = "progressBar";
		progressBar.bounds = Rect(472, 0, 224, 24);
		progressBar.parent = this;
		progressBar.minimum = 0;
		progressBar.maximum = 1000;
		progressBar.value = 0;

		btnHelp = new dfl.button.Button();
		btnHelp.name = "btnHelp";
		btnHelp.text = "?";
		btnHelp.bounds = Rect(W-32, H+28, 24, 24);
		btnHelp.parent = this;

		picBox.mouseMove ~= &OnMouseMove;
		picBox.paint ~= &OnPicPaint;
		picBox.doubleClick ~= &OnDblClick;

		btnSearch.click ~= &StartSearch;
		btnCancel.click ~= &CancelSearch;
		btnHelp.click ~= &OnHelp;

		mytid = thisTid;
		showInTaskbar = false;
		timer = new Timer;
		timer.interval = 100;
		timer.tick ~= &OnTimer;
		timer.start();
		this.closing ~= &OnClosing;
		this.minimumSize = Size(500, 200);
		this.load ~= (Form f, EventArgs a) { taskbarProgress = new TaskBarProgress(owner.handle); };

		cancelSearch = false;

		Layout(top, 0.0,0.0, W,H);
		volumeRects = top.map!(bx => bx.rect).array;
		displayBoxes();		

		font = new Font("Arial", 10);
	}

	void OnClosing(Form f, CancelEventArgs c)
	{
		cancelSearch = true;
		timer.stop();
	}

	struct SizeChange {
		Size sz;
		TickDuration t;
	}

	Nullable!SizeChange lastSizeChange;

	override void onResize(EventArgs ea)
	{
		lastSizeChange = SizeChange(clientSize, TickDuration.currSystemTick);
	}

	void Resized()
	{
		version (verbose) writeln("resized ", lastSizeChange.sz, " clientSize: ", clientSize);
		lastSizeChange.nullify();
		if (clientSize.height < 100) return; //just minimized
		W = clientSize.width;
		int prgh = progressBar.visible ? 24 : 0;
		H = clientSize.height - (36 + prgh);
		Layout(top, 0.0,0.0, W,H);
		volumeRects = top.map!(bx => bx.rect).array;
		displayBoxes();		
		lblFile.bounds = Rect(0, H + prgh, W-40, 24);
		btnHelp.bounds = Rect(W-32, H+4 + prgh, 24, 24);
	}

	void displayBoxes()
	{
		int w = W, h = H;		

		HBITMAP hbm = CreateCompatibleBitmap(Graphics.getScreen().handle, w, h);
		int[] data;
		data.length = w*h;
		boxPixMap.length = w*h;

		void drawBar(double x0, double y0, double dx, double dy, Rel r, Box bx)
		{
			int iy0 = cast(int)y0, ix0 = cast(int)x0, ix1 = cast(int) (x0 + dx), iy1 = cast(int) (y0+dy);
			if (ix1 >= w) ix1 = w;
			if (iy1 >= h) iy1 = h;
			int clr = relColor(r);
			foreach(iy; iy0 .. iy1) {
				real ky = sin(3 * cast(real)(iy - iy0) / dy);
				int di = iy * w + ix0;
				foreach(ix; ix0 .. ix1) {
					real kx = sin(3 * cast(real)(ix - ix0) / dx);
					int c = cast(int)(kx * ky * 200) + 50;
					data[di] = c * clr;
					boxPixMap[di] = bx;
					di++;
				}
			}
		}

		SimilarBoxes getsim(IFSObject item) 
		{ 
			coloring.sb = null;
			item.tell(coloring);
			return coloring.sb;
		}

		foreach(bx; top)
			bx.draw(&drawBar, &getsim);

		SetBitmapBits(hbm, data.length*4, data.ptr);
		delete data;		
		
		picBox.image = new Bitmap(hbm, true);
		picBox.size = Size(w,h);
	}

	void OnMouseMove(Control c, MouseEventArgs ma)
	{
		if (ma.x < W && ma.y < H) {
			Box box = boxPixMap[ma.y * W + ma.x];
			if (box !is null && box !is lastHoveredBox) {
				lastHoveredBox = box;
				Box resParent = box.parent;
				lblFile.text = format("%s (%s, parent: %s)", box.item.fullName(), box.item.getSize.sizeString,
									  resParent is null ? "-" : resParent.item.getSize.sizeString);
				
				pathToCurr = box.path();				
				curSimBoxes = box.similar;
				picBox.invalidate();
			}
		}
	}

	void OnDblClick(Control,EventArgs)
	{
		if (curSimBoxes is null) return;
		auto frm = new Details(curSimBoxes);
		frm.showDialog(this);
	}

	void OnPicPaint(Control c, PaintEventArgs pa)
	{
		if (curSimBoxes !is null) {
			scope greenbr = new SolidBrush(Color.fromRgb(0x80FF80));
			scope yellowbr = new SolidBrush(Color.fromRgb(0x80FFFF));
			scope redbr = new SolidBrush(Color.fromRgb(0x8080FF));
			foreach(bx; curSimBoxes.newer[0])
				pa.graphics.fillRectangle(greenbr, bx.rect);
			foreach(bx; curSimBoxes.same[0])
				pa.graphics.fillRectangle(yellowbr, bx.rect);
			foreach(bx; curSimBoxes.older[0])
				pa.graphics.fillRectangle(redbr, bx.rect);
		}

		scope Pen redpen = new Pen(Color.fromRgb(0xFF));
		foreach(rc; volumeRects) 
			pa.graphics.drawRectangle(redpen, rc);

		int[8] colors = [0xFF, 0xFFFF, 0xFF00, 0xFF0000, 0xFF00FF, 0xFFFF00, 0xFFFFFF, 0x80FF];
		int i = 0;
		Rect[] szrects;
		foreach(bx; pathToCurr) {
			auto clr = Color.fromRgb(colors[i % $]);
			scope Pen pn = new Pen(clr);
			auto rc = bx.rect();
			pa.graphics.drawRectangle(pn, rc);

			auto szstring = bx.sizeString;
			auto tsz = pa.graphics.measureText(szstring, font);
			Rect trc = Rect(rc.x, rc.y, tsz.width, tsz.height);

			foreach(szrc; szrects)
				if (trc.intersectsWith(szrc))
					trc.y = szrc.bottom;
			if (rc.contains(trc))
				pa.graphics.drawText(szstring, font, clr, trc);
			szrects ~= trc;
			i++;
		}
	}

	void EmptyMsgQueue(Tid t)
	{
		while(receiveTimeout(dur!"msecs"(0), 
					(MsgAnalyzing m) {}, 
					(MsgSearchComplete m) {}, 
					(MsgCancel m) {}
			)) {};
	}

	void OnTimer(Timer sender, EventArgs ea)
	{
		msgAnalyzing.nullify();

		bool again = false, terminated = false;
		do {
			try {
				again = receiveTimeout(dur!"msecs"(0), &RcvMsgAnalyzing, &RcvMsgSearchComplete, &RcvMsgCancel);
			} catch(LinkTerminated lt) {
				version (verbose) writeln("LinkTerminated");
				terminated = true;
			}
		} while(again);

		if (terminated) {	
			msgAnalyzing.nullify();
			version(verbose) writeln("terminated, cancelSearch=", cancelSearch, " complete=", complete);
			if (!cancelSearch && !complete) {
				lblStatus.text = "Error occured in analyzing thread.";
				errors++;
				if (errors < 3) {
					version(verbose) writeln("errors=", errors, ", retrying");
					return StartSearch(null, null);					
				}
			}
			btnSearch.visible = true;
			btnCancel.visible = false;
			progressBar.value = 0;
			taskbarProgress.enabled = false;
		} else
		if (!msgAnalyzing.isNull) {
			lblStatus.text = format("analyzing %s [%s]", msgAnalyzing.name, msgAnalyzing.sz);
			int prg = cast(int) (msgAnalyzing.progress * 1000);
			progressBar.value = prg;
			taskbarProgress.SetValue(prg, 1000);
			version (verbose) writeln("got msgAnalyzing ", nmsgAn);
		}

		if (!lastSizeChange.isNull) {
			auto dt = TickDuration.currSystemTick - lastSizeChange.t;
			if (dt.msecs > 200)
				Resized();
		}
	}

	void OnHelp(Control, EventArgs)
	{
		auto frm = new Legend();
		frm.showDialog(this);
	}

	void StartSearch(Control, EventArgs)
	{
		btnSearch.visible = false;
		btnCancel.visible = true;
		cancelSearch = false;
		complete = false;
		nmsgAn = 0;
		
		EmptyMsgQueue(thisTid);
		taskbarProgress.enabled = true;
		spawnLinked(&searchDups, cast(shared)dirs, thisTid);
		//searchDups(cast(shared)dirs, thisTid);
	}

	void CancelSearch(Control, EventArgs)
	{
		cancelSearch = true;
		btnCancel.visible = false;
		lblStatus.text = "cancelling";
	}

	void RcvMsgCancel(MsgCancel m)
	{
		version (verbose) writeln("RcvMsgCancel");
		btnSearch.visible = true;
		btnCancel.visible = false;
		progressBar.value = 0;
		taskbarProgress.enabled = false;
		lblStatus.text = "search cancelled";
		msgAnalyzing.nullify();
		GC.collect(); GC.minimize();
	}

	Nullable!MsgAnalyzing msgAnalyzing;
	bool complete;
	int nmsgAn;

	void RcvMsgAnalyzing(MsgAnalyzing m)
	{
		msgAnalyzing = m;
		nmsgAn++;
	}

	void RcvMsgSearchComplete(MsgSearchComplete m)
	{
		version (verbose) writeln("RcvMsgSearchComplete");
		complete = true;
		msgAnalyzing.nullify();
		SimilarDirs[int] sim = cast(SimilarDirs[int]) m.sim;
		SimilarFiles[string] simf = cast(SimilarFiles[string]) m.simf;
		IFSObject[int] id2dir = cast(IFSObject[int]) m.id2dir;
		IFSObject[string] fname2file = cast(IFSObject[string]) m.fname2file;

		Box[int] boxIndex;
		Box[string] fboxIndex;
		foreach(bx; top) {
			bx.addDirsToMap(boxIndex);
			bx.addFilesToMap(fboxIndex);
		}

		SimilarBoxes[int] simboxes;
		foreach(id; sim.byKey)
			simboxes[id] = simBoxesOfSets(sim[id], boxIndex, id2dir);

		SimilarBoxes[string] fsimboxes;
		foreach(id; simf.byKey)
			fsimboxes[id] = simBoxesOfSets(simf[id], fboxIndex, fname2file);

		coloring = new Coloring(simboxes, fsimboxes);
		btnCancel.visible = false;
		progressBar.visible = false;
		taskbarProgress.enabled = false;
		lblStatus.text = "";
		displayBoxes();
		picBox.bounds = Rect(0, 0, W, H);
		picBox.invalidate();
		lblFile.bounds = Rect(0, H, W-40, 24);
		btnHelp.bounds = Rect(W-32, H+4, 24, 24);
		clientSize = dfl.all.Size(W, H + 36);
		GC.collect(); GC.minimize();
		version (verbose) writeln("RcvMsgSearchComplete ok");
	}

}//class Visual

auto ids(DirInfo[] arr) { return arr.map!(di => di.ID); }
auto names(PFileInfo[] arr) { return arr.map!(fi => fi.fullName()); }

int    key(DirInfo   di) { return di.ID; }
string key(PFileInfo fi) { return fi.fullName(); }
auto keys(T)(T[] arr) { return arr.map!(key); }

shared bool cancelSearch;

template ResItem(T) { alias ResItem = Similar!(T[], T); }

auto getBigFiles(DirInfo di)  {
	return di.files.filter!(fi => fi.size > 50_000_000L).map!(fi => new PFileInfo(fi, di));
}

void searchDups(shared(DirInfo[]) _dirs, Tid gui_tid)
{
	DirInfo[] dirs = cast(DirInfo[]) _dirs;
	version (verbose) writeln("searchDups ", dirs.length);
	try {
		//dirs
		auto rc = new RelCache();
		ResItem!DirInfo[] reslist;

		Rel comp(DirInfo a, DirInfo b) { return compDirsCaching(a, b, rc); }
		void ancd(DirInfo[] ds, float prg) 
		{
			if (cancelSearch) throw new Cancelled();
			gui_tid.send(MsgAnalyzing(ds[0].name, ds.length, prg * 0.75));
			analyseCluster!(DirInfo, false)(ds, &comp, reslist);
		}

		if (dirs.length > 0)
			cluster!(DirInfo)(dirs, &ancd);

		bool[int] reported;
		foreach(r; reslist) reported[r.subj.ID] = true;
		reslist = reslist.filter!(r => r.subj.parent !is null ? (r.subj.parent.ID !in reported) : true).array;

		//big files
		PFileInfo[] bigfiles = dirs.map!getBigFiles.joiner.array;
		ResItem!PFileInfo[] freslist;

		Rel compf(PFileInfo a, PFileInfo b) { return relate(a,b,rc); }
		void ancf(PFileInfo[] fs, float prg) 
		{ 
			if (cancelSearch) throw new Cancelled();
			send(gui_tid, MsgAnalyzing(fs[0].name, fs.length, 0.75 + prg * 0.25));
			analyseCluster!(PFileInfo, false)(fs, &compf, freslist); 
		}
		if (bigfiles.length > 0)
			cluster!(PFileInfo)(bigfiles, &ancf);

		//gather results
		auto dres = gatherResults!(SimilarDirs, int, ResItem!DirInfo)(reslist);
		auto fres = gatherResults!(SimilarFiles, string, ResItem!PFileInfo)(freslist);
		version (verbose) writeln("complete, sending MsgSearchComplete");
		gui_tid.send(MsgSearchComplete(cast(shared)dres[0], cast(shared)fres[0],  cast(shared)dres[1], cast(shared)fres[1]));
	} catch(Cancelled c) {
		version (verbose) writeln("cancelled");
		gui_tid.send(MsgCancel());
	} 
	version (verbose) writeln("search thread finishes");
}

Tuple!(Sim[Key], IFSObject[Key]) gatherResults(Sim, Key, ResItem)(ResItem[] reslist)
{
	Sim[Key] sim;
	IFSObject[Key] id2ifs;
	foreach(r; reslist) {
		sim[r.subj.key] = r.fmap!(Set!Key, IFSObject)(xs => mkSet!(Key, typeof(xs.keys))(xs.keys));
		addOlder(r.older, r.subj.key, sim);
		foreach(x; chain(r.same, r.older, [r.subj]))
			id2ifs[x.key] = x;
	}
	return tuple(sim, id2ifs);
}

void addOlder(R,Key,Sim)(R old_ones, Key myid, ref Sim[Key] sim)
{
	foreach(x; old_ones) {
		auto id = key(x);
		if (id in sim) 
			sim[id].newer.add(myid);
		else {
			auto os = new Sim(Rel.ImOlder, x);
			os.newer.add(myid);
			sim[id] = os;
		}
	}
}
