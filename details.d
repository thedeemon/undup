module details;
import dfl.all, box, resizer, fileops;

class Details: dfl.form.Form
{
	// Do not modify or move this block of variables.
	//~Entice Designer variables begin here.
	dfl.label.Label label1;
	dfl.textbox.TextBox tbxSubject;
	dfl.label.Label label2;
	dfl.listview.ListView lvNewer;
	dfl.button.Button btnClose;
	//~Entice Designer variables end here.

	dfl.listview.ListView lvSubject;
	dfl.label.Label label3;
	dfl.listview.ListView lvSame;
	dfl.label.Label label4;
	dfl.listview.ListView lvOlder;
	Resizer resizer;

	this(SimilarBoxes sbx)
	{
		text = "Details";
		clientSize = dfl.all.Size(696, 506);
		int y = 8;
		y = addList([sbx.subj],     y, label1, lvSubject, "Subject:", 64);
		y = addList(sbx.newer[1],  y, label2, lvNewer, "These objects are newer:");
		y = addList(sbx.same[1],   y, label3, lvSame, "These objects are same:");
		y = addList(sbx.older[1],  y, label4, lvOlder, "These objects are older:");

		btnClose = new dfl.button.Button();
		btnClose.name = "btnClose";
		btnClose.text = "Close";
		btnClose.bounds = dfl.all.Rect(608, y + 8, 72, 24);
		btnClose.parent = this;

		clientSize = Size(696, y + 40);

		btnClose.click ~= (Control c, EventArgs a) => close();

		showInTaskbar = false;
		resizer = new Resizer(this);
		resizer.let(lvSubject, XCoord.resizes, YCoord.stays, &lvResized);
		foreach(lv; [lvNewer, lvSame, lvOlder])
			resizer.let(lv, XCoord.resizes, YCoord.scales, &lvResized);
		foreach(lbl; [label2, label3, label4])
			resizer.let(lbl, XCoord.stays, YCoord.scalesPos);
		resizer.let(btnClose, XCoord.moves, YCoord.moves);
		resizer.prepare();

		this.load ~= (Form f, EventArgs a) { centerToParent(); };
	}

	override void onResize(EventArgs ea) { resizer.go(); }

	void lvResized(Control c)
	{
		auto lv = cast(ListView) c;
		lv.columns[0].width = lv.bounds.width - 20 - lv.columns[1].width;
	}
	
	int addList(IFSObject[] items, int y, ref Label label, ref ListView lv, string caption, int height = 160)
	{
		if (items.length > 0) {
			label = new dfl.label.Label();
			label.name = caption;
			label.text = caption;
			label.textAlign = dfl.all.ContentAlignment.MIDDLE_LEFT;
			label.bounds = dfl.all.Rect(8, y, 408, 24);
			label.parent = this;

			lv = new dfl.listview.ListView();
			lv.name = "lv";
			lv.view = dfl.all.View.DETAILS;
			lv.allowColumnReorder = true;
			lv.fullRowSelect = true;
			lv.bounds = dfl.all.Rect(8, y+32, 672, height);
			lv.parent = this;
			lv.labelWrap = true;			

			auto colnames = ["Path", "Size"];
			auto colwidths = [586, 70];
			foreach(i; 0..colnames.length) {
				auto col = new ColumnHeader(colnames[i]);
				col.width = colwidths[i];
				lv.columns.add(col);
			}

			foreach(item; items) 
				lv.addRow([item.fullName, item.getSize.sizeString]);

			y = lv.bounds.bottom + 8;
		}
		return y;
	}
}

