using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using System.Xml.Linq;

[assembly: System.Reflection.AssemblyVersion("1.3.0.0")]
[assembly: System.Reflection.AssemblyFileVersion("1.3.0.0")]
[assembly: System.Reflection.AssemblyProduct("Brick Overlay")]

namespace BrickOverlay {
    public sealed class Appearance {
        public int Palette, Width = 850, Height = 652, Opacity = 22;
        public int Mode, BrickWidth = 150, BrickHeight = 48, MinimumHeight = 24, MaximumHeight = 96, Bands = 4;
        public bool RandomWidth;
        public int MinimumWidth = 80, MaximumWidth = 240;
        public uint Seed = 731;
        public string[] Colors = { "F26F6C", "F5C84C", "68B995", "58B6D3", "967BC5" };
        public static readonly string[][] Palettes = {
            new [] { "F26F6C", "F5C84C", "68B995", "58B6D3", "967BC5" },
            new [] { "CD5C5C", "FF7F50", "FFD700", "FFB6C1", "CD853F" },
            new [] { "6495ED", "008080", "87CEEB", "7B68EE", "DDA0DD" },
            // Original Mac green preset, resolved to sRGB in macOS Aqua appearance.
            new [] { "34C759", "00C8B3", "00C3D0", "FFCC00", "AC7F5E" },
            new [] { "FFB6C1", "EEE8AA", "98FB98", "E0FFFF", "D8BFD8" }
        };
        public static int Clamp(int n, int min, int max) { return Math.Min(max, Math.Max(min,n)); }
        public static string Hex(string value) {
            if (value == null) return null;
            string h = value.Trim().Replace("#", "").ToUpperInvariant();
            if (h.Length != 6) return null;
            foreach (char c in h) if ("0123456789ABCDEF".IndexOf(c) < 0) return null;
            return h;
        }
        public void Normalize() {
            Width = Clamp(Width,100,6000); Height = Clamp(Height,48,4000); Opacity = Clamp(Opacity,5,65);
            Mode = Clamp(Mode,0,2); BrickWidth = Clamp(BrickWidth,24,1200); BrickHeight = Clamp(BrickHeight,8,1000);
            MinimumHeight = Clamp(MinimumHeight,8,1000); MaximumHeight = Clamp(MaximumHeight,MinimumHeight,1000);
            MinimumWidth = Clamp(MinimumWidth,24,1200); MaximumWidth = Clamp(MaximumWidth,MinimumWidth,1200);
            Bands = Clamp(Bands,2,16);
            List<string> colors = new List<string>();
            foreach (string c in Colors ?? new string[0]) { string h = Hex(c); if (h != null && colors.Count < 12) colors.Add(h); }
            if (colors.Count == 0) colors.Add("58B6D3"); Colors = colors.ToArray();
        }
        public Appearance Copy() { Appearance a = (Appearance)MemberwiseClone(); a.Colors = (string[])Colors.Clone(); return a; }
    }

    public struct Tile {
        public int X,Y,Width,Height,Color;
        public Tile(int x,int y,int w,int h,int color) { X=x;Y=y;Width=w;Height=h;Color=color; }
    }
    public static class Layout {
        public static uint Hash(uint seed,int col,int row) {
            unchecked { uint x = seed + (uint)col * 374761393u + (uint)row * 668265263u; x = (x ^ (x >> 13)) * 1274126177u; return x ^ (x >> 16); }
        }
        static void Add(List<Tile> list,Appearance a,int x,int y,int w,int h,int color) {
            int left=Math.Max(0,x), top=Math.Max(0,y), right=Math.Min(a.Width,x+w), bottom=Math.Min(a.Height,y+h);
            if (right>left && bottom>top) list.Add(new Tile(left,top,right-left,bottom-top,color%a.Colors.Length));
        }
        public static List<Tile> Tiles(Appearance value) {
            Appearance a=value.Copy();a.Normalize();List<Tile> list=new List<Tile>();
            if (a.Mode==2) {
                int gap=Math.Min(3,(a.Height-a.Bands)/(a.Bands-1));
                int available=a.Height-(a.Bands-1)*gap;
                for(int i=0;i<a.Bands;i++) { int top=i*available/a.Bands+i*gap, end=(i+1)*available/a.Bands+i*gap; Add(list,a,0,top,a.Width,end-top,i); }
            } else if (a.Mode==1 && a.RandomWidth) {
                // Random row heights and individual widths fully tile the surface.
                for(int row=0,y=0;y<a.Height;row++) {
                    int h=a.MinimumHeight+(int)(Hash(a.Seed,0,row)%(uint)(a.MaximumHeight-a.MinimumHeight+1));
                    for(int col=0,x=0;x<a.Width;col++) {
                        int w=a.MinimumWidth+(int)(Hash(a.Seed ^ 0x9E3779B9u,col,row)%(uint)(a.MaximumWidth-a.MinimumWidth+1));
                        Add(list,a,x,y,w,h,col+row*2);x+=w+3;
                    }
                    y+=h+3;
                }
            } else if (a.Mode==1) {
                for(int col=0,x=0;x<a.Width;col++,x+=a.BrickWidth+3) {
                    for(int row=0,y=0;y<a.Height;row++) { int h=a.MinimumHeight+(int)(Hash(a.Seed,col,row)%(uint)(a.MaximumHeight-a.MinimumHeight+1)); Add(list,a,x,y,a.BrickWidth,h,col+row*2); y+=h+3; }
                }
            } else {
                for(int row=0,y=0;y<a.Height;row++,y+=a.BrickHeight+3) {
                    for(int col=0,x=row%2==0?0:-a.BrickWidth/2;x<a.Width;col++,x+=a.BrickWidth+3) Add(list,a,x,y,a.BrickWidth,a.BrickHeight,col+row*2);
                }
            }
            return list;
        }
    }

    public sealed class Store {
        public Appearance Current = new Appearance();
        public Appearance Default;
        public readonly Dictionary<string, Appearance> Presets = new Dictionary<string, Appearance>();
        public readonly string PathName;
        private readonly string legacy;
        // Keep the old stable settings intact; import the tested preview on first launch.
        public Store() : this(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "BrickOverlay", "settings-v1.3.xml"),ImportPath()) {}
        private static string ImportPath() {
            string appData=Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            string preview=Path.Combine(appData,"BrickOverlay-Preview","settings.xml");
            return File.Exists(preview)?preview:Path.Combine(appData,"BrickOverlay","settings.xml");
        }
        public Store(string path,string legacyPath) { PathName=path;legacy=legacyPath; }
        static int Number(XElement e,string key,int fallback) { int n;return e!=null && int.TryParse((string)e.Attribute(key),out n)?n:fallback; }
        public static Appearance Read(XElement e) {
            Appearance a=new Appearance();
            a.Palette=Appearance.Clamp(Number(e,"palette",0),0,4);
            a.Width=Number(e,"width",850);a.Height=Number(e,"height",652);a.Opacity=Number(e,"opacity",22);
            a.Mode=Number(e,"mode",0);a.BrickWidth=Number(e,"brickWidth",150);a.BrickHeight=Number(e,"brickHeight",48);
            a.MinimumHeight=Number(e,"minHeight",24);a.MaximumHeight=Number(e,"maxHeight",96);a.Bands=Number(e,"bands",4);
            a.RandomWidth=Number(e,"randomWidth",0)!=0;a.MinimumWidth=Number(e,"minWidth",80);a.MaximumWidth=Number(e,"maxWidth",240);
            uint seed; if(e!=null && uint.TryParse((string)e.Attribute("seed"),out seed))a.Seed=seed;
            string colors=e==null?null:(string)e.Attribute("colors");
            a.Colors=colors==null?(string[])Appearance.Palettes[a.Palette].Clone():colors.Split(',');a.Normalize();return a;
        }
        public static XElement Write(string name,Appearance a) {
            return new XElement(name,new XAttribute("palette",a.Palette),new XAttribute("width",a.Width),new XAttribute("height",a.Height),new XAttribute("opacity",a.Opacity),new XAttribute("mode",a.Mode),new XAttribute("brickWidth",a.BrickWidth),new XAttribute("brickHeight",a.BrickHeight),new XAttribute("minHeight",a.MinimumHeight),new XAttribute("maxHeight",a.MaximumHeight),new XAttribute("randomWidth",a.RandomWidth?1:0),new XAttribute("minWidth",a.MinimumWidth),new XAttribute("maxWidth",a.MaximumWidth),new XAttribute("bands",a.Bands),new XAttribute("seed",a.Seed),new XAttribute("colors",String.Join(",",a.Colors)));
        }
        public void Load() {
            string source=File.Exists(PathName)?PathName:legacy;
            if(source==null || !File.Exists(source))return;
            try {
                XElement root=XDocument.Load(source).Root;
                Current=Read(root.Element("Current"));
                Default=root.Element("Default")==null?null:Read(root.Element("Default"));
                XElement saved=root.Element("Presets");
                if(saved!=null)foreach(XElement e in saved.Elements("Preset")) { string name=(string)e.Attribute("name");if(!String.IsNullOrWhiteSpace(name))Presets[name]=Read(e); }
                if(Default!=null)Current=Default.Copy();
            } catch { Current=new Appearance();Default=null;Presets.Clear(); }
        }
        public void Save() {
            Directory.CreateDirectory(Path.GetDirectoryName(PathName));
            XElement root=new XElement("BrickOverlay",Write("Current",Current));
            if(Default!=null)root.Add(Write("Default",Default));
            XElement presets=new XElement("Presets");
            foreach(KeyValuePair<string,Appearance> item in Presets) { XElement e=Write("Preset",item.Value);e.Add(new XAttribute("name",item.Key));presets.Add(e); }
            root.Add(presets);new XDocument(root).Save(PathName);
        }
    }

    internal static class Native {
        public const int GWL_EXSTYLE = -20;
        public const int WS_EX_TRANSPARENT = 0x20;
        [DllImport("user32.dll", EntryPoint = "GetWindowLong", SetLastError = true)]
        public static extern int GetWindowLong(IntPtr hWnd, int index);
        [DllImport("user32.dll", EntryPoint = "SetWindowLong", SetLastError = true)]
        public static extern int SetWindowLong(IntPtr hWnd, int index, int value);
    }

    public sealed class OverlayForm : Form {
        public bool Moving;
        public Appearance Configuration = new Appearance();
        private List<Tile> tiles = new List<Tile>();
        private Point dragStart;
        private Point formStart;
        public OverlayForm() {
            FormBorderStyle = FormBorderStyle.None;
            ShowInTaskbar = false;
            TopMost = true;
            BackColor = Color.FromArgb(1,2,3);
            TransparencyKey = BackColor;
            DoubleBuffered = true;
            StartPosition = FormStartPosition.Manual;
            MouseDown += delegate(object sender, MouseEventArgs e) { if (Moving && e.Button == MouseButtons.Left) { dragStart = Cursor.Position; formStart = Location; } };
            MouseMove += delegate(object sender, MouseEventArgs e) {
                if (Moving && e.Button == MouseButtons.Left) Location = new Point(formStart.X + Cursor.Position.X - dragStart.X, formStart.Y + Cursor.Position.Y - dragStart.Y);
            };
        }

        public void SetClickThrough(bool enabled) {
            int value = Native.GetWindowLong(Handle, Native.GWL_EXSTYLE);
            value = enabled ? value | Native.WS_EX_TRANSPARENT : value & ~Native.WS_EX_TRANSPARENT;
            Native.SetWindowLong(Handle, Native.GWL_EXSTYLE, value);
        }

        public void UpdateAppearance(Appearance a) { Configuration=a.Copy();tiles=BrickOverlay.Layout.Tiles(a);Invalidate(); }
        protected override void OnPaint(PaintEventArgs e) {
            base.OnPaint(e); e.Graphics.Clear(BackColor);
            Color[] colors=new Color[Configuration.Colors.Length];
            for(int i=0;i<colors.Length;i++) { colors[i]=ColorTranslator.FromHtml("#"+Configuration.Colors[i]);if(colors[i].ToArgb()==BackColor.ToArgb())colors[i]=Color.FromArgb(1,2,4); }
            using (System.Drawing.Drawing2D.Matrix matrix=new System.Drawing.Drawing2D.Matrix()) {
                float sx=Width/(float)Configuration.Width, sy=Height/(float)Configuration.Height;
                matrix.Scale(sx,sy);e.Graphics.Transform=matrix;
                foreach(Tile tile in tiles)using(Brush brush=new SolidBrush(colors[tile.Color]))e.Graphics.FillRectangle(brush,tile.X,tile.Y,tile.Width,tile.Height);
            }
        }
    }

    public sealed class Controller : ApplicationContext {
        private readonly Store store = new Store();
        private readonly OverlayForm overlay = new OverlayForm();
        private readonly Form buttonForm = new Form();
        private readonly Button button = new Button();
        private readonly NotifyIcon tray = new NotifyIcon();
        private Form appearance;
        private readonly Dictionary<string,TrackBar> bars=new Dictionary<string,TrackBar>();
        private readonly Dictionary<string,NumericUpDown> numbers=new Dictionary<string,NumericUpDown>();
        private ComboBox modeBox;
        private CheckBox randomWidthBox;
        private readonly List<Button> swatches=new List<Button>();
        private int chosenColor;
        private TextBox hexBox;
        private Label hint;
        private Button shuffleButton, addButton, removeButton;
        private bool placing;
        private bool syncing;
        private static readonly string[] paletteNames = { "彩色砖块", "暖色", "冷色", "绿色", "粉彩" };

        public Controller() {
            store.Load();
            overlay.Location = new Point(80, 100);
            Apply(store.Current);
            overlay.LocationChanged += delegate { PlaceButton(); };
            overlay.Show();
            overlay.SetClickThrough(true);
            buttonForm.FormBorderStyle = FormBorderStyle.None;
            buttonForm.ShowInTaskbar = false;
            buttonForm.TopMost = true;
            buttonForm.StartPosition = FormStartPosition.Manual;
            buttonForm.Size = new Size(36, 36);
            buttonForm.Controls.Add(button);
            button.Dock = DockStyle.Fill;
            button.Text = "⋯";
            button.Click += delegate { ShowMenu(); };
            PlaceButton();
            buttonForm.Show();
            tray.Icon = SystemIcons.Application;
            tray.Text = "Brick Overlay";
            tray.Visible = true;
            tray.ContextMenuStrip = new ContextMenuStrip();
            tray.ContextMenuStrip.Items.Add("显示/隐藏透卡", null, delegate { ToggleVisible(); });
            tray.ContextMenuStrip.Items.Add("Appearance...", null, delegate { ShowAppearance(); });
            tray.ContextMenuStrip.Items.Add("退出 / Quit", null, delegate { ExitThread(); });
            ShowAppearance();
        }

        private void PlaceButton() {
            if(placing)return;placing=true;
            try {
                Rectangle area=Screen.FromControl(overlay).WorkingArea;
                int rightmost=area.Right-overlay.Width-44;
                int x=Math.Min(Math.Max(overlay.Left,area.Left),rightmost);
                int y=Math.Min(Math.Max(overlay.Top,area.Top),area.Bottom-50);
                if(x!=overlay.Left || y!=overlay.Top)overlay.Location=new Point(x,y);
                int buttonY=Math.Max(area.Top,Math.Min(area.Bottom-36,overlay.Top+(overlay.Height-36)/2));
                buttonForm.Location=new Point(overlay.Right+8,buttonY);
            } finally { placing=false; }
        }
        private void Apply(Appearance a) {
            a.Normalize();overlay.Size=new Size(a.Width,a.Height);overlay.Opacity=a.Opacity/100.0;
            overlay.UpdateAppearance(a);
            if(buttonForm.IsHandleCreated)PlaceButton();SyncAppearance();
        }

        private void SaveCurrent() { store.Save(); }

        private void ShowMenu() {
            ContextMenuStrip menu = new ContextMenuStrip();
            menu.Items.Add(overlay.Visible ? "隐藏透卡" : "显示透卡", null, delegate { ToggleVisible(); });
            menu.Items.Add(overlay.Moving ? "锁定位置" : "解锁移动", null, delegate {
                overlay.Moving = !overlay.Moving;
                overlay.SetClickThrough(!overlay.Moving);
            });
            menu.Items.Add("Appearance...", null, delegate { ShowAppearance(); });
            menu.Items.Add("保存为默认外观", null, delegate { store.Default = store.Current.Copy(); store.Save(); });
            menu.Items.Add("恢复默认外观", null, delegate { store.Current = store.Default==null?new Appearance():store.Default.Copy();Apply(store.Current);SaveCurrent(); });
            ToolStripMenuItem presets = new ToolStripMenuItem("预设");
            for (int i = 0; i < paletteNames.Length; i++) {
                int index = i;
                presets.DropDownItems.Add(paletteNames[i], null, delegate { store.Current.Palette = index; store.Current.Colors = (string[])Appearance.Palettes[index].Clone(); Apply(store.Current); SaveCurrent(); });
            }
            presets.DropDownItems.Add(new ToolStripSeparator());
            presets.DropDownItems.Add("保存当前为用户预设...", null, delegate { SavePreset(); });
            foreach (KeyValuePair<string, Appearance> item in store.Presets) {
                string name = item.Key;
                presets.DropDownItems.Add(name, null, delegate { store.Current = store.Presets[name].Copy(); Apply(store.Current); SaveCurrent(); });
            }
            menu.Items.Add(presets);
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add("退出", null, delegate { ExitThread(); });
            menu.Show(button, new Point(0, button.Height));
        }

        private void ToggleVisible() {
            bool show = !overlay.Visible;
            overlay.Visible = show;
            buttonForm.Visible = show;
            if (show) PlaceButton();
        }

        private static Label MakeLabel(string text, int x, int y, int width) {
            return new Label { Text = text, Left = x, Top = y, Width = width, Height = 22 };
        }

        private void ShowAppearance() {
            if (appearance == null || appearance.IsDisposed) BuildAppearance();
            SyncAppearance();
            appearance.Show();
            appearance.BringToFront();
        }

        private void Row(string key,string title,int y,int min,int max,string unit) {
            appearance.Controls.Add(MakeLabel(title,20,y+4,176));
            TrackBar bar=new TrackBar { Left=194,Top=y,Width=220,Height=30,Minimum=min,Maximum=max,TickStyle=TickStyle.None,SmallChange=1,LargeChange=10 };
            NumericUpDown number=new NumericUpDown { Left=420,Top=y,Width=86,Height=26,Minimum=min,Maximum=max,DecimalPlaces=0,TextAlign=HorizontalAlignment.Right,ThousandsSeparator=false };
            bars[key]=bar;numbers[key]=number;
            appearance.Controls.Add(bar);appearance.Controls.Add(number);appearance.Controls.Add(MakeLabel(unit,512,y+4,32));
            bar.ValueChanged+=delegate { if(!syncing)SetNumber(key,bar.Value); };
            number.ValueChanged+=delegate { if(!syncing)SetNumber(key,(int)number.Value); };
        }
        private void SetNumber(string key,int n) {
            Appearance a=store.Current;
            switch(key) {
                case "width":a.Width=n;break;case "height":a.Height=n;break;case "opacity":a.Opacity=n;break;
                case "brickWidth":a.BrickWidth=n;break;case "brickHeight":a.BrickHeight=n;break;
                case "min":a.MinimumHeight=n;a.MaximumHeight=Math.Max(n,a.MaximumHeight);break;
                case "max":a.MaximumHeight=n;a.MinimumHeight=Math.Min(n,a.MinimumHeight);break;
                case "minWidth":a.MinimumWidth=n;a.MaximumWidth=Math.Max(n,a.MaximumWidth);break;
                case "maxWidth":a.MaximumWidth=n;a.MinimumWidth=Math.Min(n,a.MinimumWidth);break;
                case "bands":a.Bands=n;break;
            }
            Apply(a);SaveCurrent();
        }
        private void BuildAppearance() {
            appearance=new Form { Text="Appearance - Brick Overlay 1.3",ClientSize=new Size(570,650),FormBorderStyle=FormBorderStyle.FixedDialog,MaximizeBox=false,MinimizeBox=false,StartPosition=FormStartPosition.CenterScreen,AutoScroll=true,TopMost=true };
            appearance.FormClosing+=delegate(object sender,FormClosingEventArgs e) { if(e.CloseReason==CloseReason.UserClosing){e.Cancel=true;appearance.Hide();} };
            appearance.Controls.Add(MakeLabel("阅读模式 / Mode",20,18,165));
            modeBox=new ComboBox { Left=194,Top=14,Width=340,DropDownStyle=ComboBoxStyle.DropDownList };
            modeBox.Items.AddRange(new [] { "砖块 / Bricks", "随机砖块 / Random bricks", "文献阅读 / Document" });
            modeBox.SelectedIndexChanged+=delegate { if(!syncing && modeBox.SelectedIndex>=0) {store.Current.Mode=modeBox.SelectedIndex;Apply(store.Current);SaveCurrent();} };
            appearance.Controls.Add(modeBox);hint=MakeLabel("",20,48,530);appearance.Controls.Add(hint);
            Row("width","透卡宽 / Width",80,100,6000,"px");Row("height","透卡高 / Height",116,48,4000,"px");Row("opacity","着色强度 / Tint",152,5,65,"%");
            Row("brickWidth","砖块宽 / Brick width",200,24,1200,"px");Row("brickHeight","砖块高 / Brick height",236,8,1000,"px");
            Row("min","随机最小高 / Min",272,8,1000,"px");Row("max","随机最大高 / Max",308,8,1000,"px");
            randomWidthBox=new CheckBox {Text="同时随机宽度 / Randomize widths",Left=20,Top=344,Width=510,Height=24};
            randomWidthBox.CheckedChanged+=delegate {if(!syncing){store.Current.RandomWidth=randomWidthBox.Checked;Apply(store.Current);SaveCurrent();}};appearance.Controls.Add(randomWidthBox);
            Row("minWidth","最小宽 / Min width",380,24,1200,"px");Row("maxWidth","最大宽 / Max width",416,24,1200,"px");
            Row("bands","文献分段 / Sections",452,2,16,"");
            shuffleButton=new Button { Text="重新随机 / Shuffle",Left=20,Top=490,Width=180,Height=30 };
            shuffleButton.Click+=delegate {unchecked {store.Current.Seed++;}Apply(store.Current);SaveCurrent();};appearance.Controls.Add(shuffleButton);
            appearance.Controls.Add(MakeLabel("色板 / Palette (1-12)",20,535,270));
            ComboBox loadPalette=new ComboBox { Left=310,Top=528,Width=220,DropDownStyle=ComboBoxStyle.DropDownList };
            loadPalette.Items.Add("载入配色 / Load palette");loadPalette.Items.AddRange(paletteNames);loadPalette.SelectedIndex=0;
            loadPalette.SelectedIndexChanged+=delegate { if(loadPalette.SelectedIndex>0){store.Current.Colors=(string[])Appearance.Palettes[loadPalette.SelectedIndex-1].Clone();chosenColor=0;loadPalette.SelectedIndex=0;Apply(store.Current);SaveCurrent();} };appearance.Controls.Add(loadPalette);
            for(int i=0;i<12;i++) { int index=i;Button b=new Button { Left=20+i*43,Top=564,Width=37,Height=30,FlatStyle=FlatStyle.Flat,UseVisualStyleBackColor=false };b.Click+=delegate{chosenColor=index;SyncAppearance();};swatches.Add(b);appearance.Controls.Add(b); }
            Button pick=new Button { Text="选色 / Color",Left=20,Top=608,Width=115,Height=30 };
            pick.Click+=delegate { using(ColorDialog dialog=new ColorDialog { FullOpen=true,Color=ColorTranslator.FromHtml("#"+store.Current.Colors[chosenColor]) }) {
                if(dialog.ShowDialog(appearance)==DialogResult.OK){store.Current.Colors[chosenColor]=dialog.Color.R.ToString("X2")+dialog.Color.G.ToString("X2")+dialog.Color.B.ToString("X2");Apply(store.Current);SaveCurrent();}
            }};appearance.Controls.Add(pick);
            hexBox=new TextBox { Left=145,Top=611,Width=105 };hexBox.Leave+=delegate{ApplyHex();};hexBox.KeyDown+=delegate(object sender,KeyEventArgs e){if(e.KeyCode==Keys.Enter){ApplyHex();e.SuppressKeyPress=true;}};appearance.Controls.Add(hexBox);
            addButton=new Button { Text="＋ 添加 / Add",Left=264,Top=608,Width=120,Height=30 };
            addButton.Click+=delegate {List<string> colors=new List<string>(store.Current.Colors);if(colors.Count>=12)return;colors.Add(colors[chosenColor]);chosenColor=colors.Count-1;store.Current.Colors=colors.ToArray();Apply(store.Current);SaveCurrent();};appearance.Controls.Add(addButton);
            removeButton=new Button { Text="－ 删除 / Remove",Left=394,Top=608,Width=140,Height=30 };
            removeButton.Click+=delegate {List<string> colors=new List<string>(store.Current.Colors);if(colors.Count<=1)return;colors.RemoveAt(chosenColor);chosenColor=Math.Min(chosenColor,colors.Count-1);store.Current.Colors=colors.ToArray();Apply(store.Current);SaveCurrent();};appearance.Controls.Add(removeButton);
            Button saveDefault=new Button { Text="保存为默认 / Save default",Left=20,Top=656,Width=245,Height=30 };saveDefault.Click+=delegate {store.Default=store.Current.Copy();store.Save();hint.Text="已保存默认外观 / Default saved";};appearance.Controls.Add(saveDefault);
            Button savePreset=new Button { Text="保存个人预设 / Save preset",Left=280,Top=656,Width=254,Height=30 };savePreset.Click+=delegate {SavePreset();};appearance.Controls.Add(savePreset);
            appearance.Controls.Add(MakeLabel("输入数值后按 Tab 或离开输入框生效 / Tab to apply",20,703,530));
            appearance.Controls.Add(MakeLabel("文献模式按区域分段；不自动识别文章段落。",20,729,530));
            appearance.AutoScrollMinSize=new Size(550,758);
            appearance.ClientSize=new Size(570,Math.Min(650,Math.Max(300,Screen.PrimaryScreen.WorkingArea.Height-80)));
            SyncAppearance();
        }
        private void ApplyHex() {
            if(syncing)return;string value=Appearance.Hex(hexBox.Text);
            if(value==null){hint.Text="请输入 #RRGGBB / Enter #RRGGBB";SyncAppearance();return;}
            store.Current.Colors[chosenColor]=value;Apply(store.Current);SaveCurrent();
        }
        private void SyncAppearance() {
            if(appearance==null || appearance.IsDisposed || modeBox==null || numbers.Count<10)return;
            syncing=true;
            try {
                Appearance a=store.Current;
                modeBox.SelectedIndex=a.Mode;
                hint.Text=new [] { "等高错缝砖块 / Uniform staggered bricks", a.RandomWidth ? "每行随机高、每块随机宽 / Random rows and widths" : "每块独立高度 / Random heights; fixed width", "整宽大色块划分阅读区 / Full-width reading bands" }[a.Mode];
                var values=new Dictionary<string,int> {{"width",a.Width},{"height",a.Height},{"opacity",a.Opacity},{"brickWidth",a.BrickWidth},{"brickHeight",a.BrickHeight},{"min",a.MinimumHeight},{"max",a.MaximumHeight},{"bands",a.Bands},{"minWidth",a.MinimumWidth},{"maxWidth",a.MaximumWidth}};
                foreach(var pair in values){numbers[pair.Key].Value=pair.Value;bars[pair.Key].Value=pair.Value;}
                foreach(string key in new [] {"brickWidth","brickHeight","min","max","minWidth","maxWidth","bands"}) {
                    bool enabled=key=="bands"?a.Mode==2:key=="brickWidth"?(a.Mode==0 || (a.Mode==1 && !a.RandomWidth)):(key=="minWidth" || key=="maxWidth")?(a.Mode==1 && a.RandomWidth):key=="brickHeight"?a.Mode==0:a.Mode==1;
                    numbers[key].Enabled=enabled;bars[key].Enabled=enabled;
                }
                if(shuffleButton==null)return;
                randomWidthBox.Checked=a.RandomWidth;randomWidthBox.Enabled=a.Mode==1;
                shuffleButton.Enabled=a.Mode==1;chosenColor=Math.Min(chosenColor,a.Colors.Length-1);
                for(int i=0;i<swatches.Count;i++){Button b=swatches[i];b.Visible=i<a.Colors.Length;if(b.Visible){b.BackColor=ColorTranslator.FromHtml("#"+a.Colors[i]);b.FlatAppearance.BorderSize=i==chosenColor?3:1;}}
                if(hexBox!=null)hexBox.Text="#"+a.Colors[chosenColor];if(addButton!=null)addButton.Enabled=a.Colors.Length<12;if(removeButton!=null)removeButton.Enabled=a.Colors.Length>1;
            } finally {syncing=false;}
        }

        private void SavePreset() {
            using (Form prompt = new Form { Text = "保存用户预设", ClientSize = new Size(280, 105), FormBorderStyle = FormBorderStyle.FixedDialog, StartPosition = FormStartPosition.CenterScreen }) {
                TextBox input = new TextBox { Left = 16, Top = 16, Width = 248 };
                Button save = new Button { Text = "保存", Left = 174, Top = 55, Width = 90, DialogResult = DialogResult.OK };
                prompt.Controls.Add(input); prompt.Controls.Add(save); prompt.AcceptButton = save;
                if (prompt.ShowDialog() == DialogResult.OK && !String.IsNullOrWhiteSpace(input.Text)) {
                    store.Presets[input.Text.Trim()] = store.Current.Copy();
                    store.Save();
                }
            }
        }

        protected override void ExitThreadCore() {
            store.Save();
            tray.Visible = false;
            tray.Dispose();
            if (appearance != null) appearance.Dispose();
            buttonForm.Dispose();
            overlay.Dispose();
            base.ExitThreadCore();
        }
    }

    public static class Program {
        [STAThread]
        public static void Main() {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new Controller());
        }
    }
}
