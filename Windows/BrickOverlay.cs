using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using System.Xml.Linq;

namespace BrickOverlay {
    public sealed class Appearance {
        public int Palette = 0;
        public int Width = 850;
        public int Height = 240;
        public int Opacity = 22;

        public Appearance Copy() {
            return new Appearance { Palette = Palette, Width = Width, Height = Height, Opacity = Opacity };
        }
    }

    public sealed class Store {
        public Appearance Current = new Appearance();
        public Appearance Default = new Appearance();
        public readonly Dictionary<string, Appearance> Presets = new Dictionary<string, Appearance>();
        private readonly string path = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "BrickOverlay", "settings.xml");

        private static int Number(XElement element, string name, int fallback) {
            int result;
            return element != null && int.TryParse((string)element.Attribute(name), out result) ? result : fallback;
        }

        private static Appearance Read(XElement element) {
            return new Appearance {
                Palette = Number(element, "palette", 0),
                Width = Number(element, "width", 850),
                Height = Number(element, "height", 240),
                Opacity = Number(element, "opacity", 22)
            };
        }

        private static XElement Write(string name, Appearance a) {
            return new XElement(name, new XAttribute("palette", a.Palette), new XAttribute("width", a.Width),
                new XAttribute("height", a.Height), new XAttribute("opacity", a.Opacity));
        }

        public void Load() {
            if (!File.Exists(path)) return;
            try {
                XElement root = XDocument.Load(path).Root;
                Current = Read(root.Element("Current"));
                Default = Read(root.Element("Default"));
                XElement saved = root.Element("Presets");
                if (saved != null) foreach (XElement item in saved.Elements("Preset")) {
                    string name = (string)item.Attribute("name");
                    if (!String.IsNullOrWhiteSpace(name)) Presets[name] = Read(item);
                }
                Current = Default.Copy();
            } catch { Current = new Appearance(); Default = new Appearance(); Presets.Clear(); }
        }

        public void Save() {
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            XElement presets = new XElement("Presets");
            foreach (KeyValuePair<string, Appearance> pair in Presets) {
                XElement item = Write("Preset", pair.Value);
                item.Add(new XAttribute("name", pair.Key));
                presets.Add(item);
            }
            new XDocument(new XElement("BrickOverlay", Write("Current", Current), Write("Default", Default), presets)).Save(path);
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
        public int Palette;
        private Point dragStart;
        private Point formStart;
        private readonly Color[][] palettes = new Color[][] {
            new Color[] { Color.FromArgb(242,111,108), Color.FromArgb(245,200,76), Color.FromArgb(104,185,149), Color.FromArgb(88,182,211), Color.FromArgb(150,123,197) },
            new Color[] { Color.IndianRed, Color.Coral, Color.Gold, Color.LightPink, Color.Peru },
            new Color[] { Color.CornflowerBlue, Color.Teal, Color.SkyBlue, Color.MediumSlateBlue, Color.Plum },
            new Color[] { Color.MediumSeaGreen, Color.MediumAquamarine, Color.Teal, Color.Khaki, Color.OliveDrab },
            new Color[] { Color.LightPink, Color.PaleGoldenrod, Color.PaleGreen, Color.LightCyan, Color.Thistle }
        };

        public OverlayForm() {
            FormBorderStyle = FormBorderStyle.None;
            ShowInTaskbar = false;
            TopMost = true;
            BackColor = Color.Magenta;
            TransparencyKey = Color.Magenta;
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

        protected override void OnPaint(PaintEventArgs e) {
            base.OnPaint(e);
            Color[] colors = palettes[Math.Max(0, Math.Min(Palette, palettes.Length - 1))];
            e.Graphics.Clear(Color.Magenta);
            const int w = 150, h = 48, gap = 3;
            for (int row = 0; row * (h + gap) < Height; row++) {
                int offset = row % 2 == 0 ? 0 : -w / 2;
                for (int col = 0; col * (w + gap) + offset < Width; col++) {
                    using (Brush brush = new SolidBrush(colors[(col + row * 2) % colors.Length]))
                        e.Graphics.FillRectangle(brush, col * (w + gap) + offset, row * (h + gap), w, h);
                }
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
        private TrackBar widthBar, heightBar, opacityBar;
        private ComboBox paletteBox;
        private Label widthLabel, heightLabel;
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
            tray.ContextMenuStrip.Items.Add("退出", null, delegate { ExitThread(); });
        }

        private void PlaceButton() {
            Rectangle area = Screen.FromControl(overlay).WorkingArea;
            int maxWidth = Math.Max(100, area.Width - 50);
            if (overlay.Width > maxWidth) overlay.Width = maxWidth;
            int x = Math.Max(area.Left, Math.Min(overlay.Left, area.Right - overlay.Width - 44));
            if (x != overlay.Left) overlay.Left = x;
            buttonForm.Location = new Point(overlay.Right + 8, overlay.Top + (overlay.Height - buttonForm.Height) / 2);
        }

        private void Apply(Appearance a) {
            a.Palette = Math.Max(0, Math.Min(4, a.Palette));
            a.Width = Math.Max(100, Math.Min(1600, a.Width));
            a.Height = Math.Max(48, Math.Min(1000, a.Height));
            a.Opacity = Math.Max(8, Math.Min(45, a.Opacity));
            overlay.Size = new Size(a.Width, a.Height);
            overlay.Palette = a.Palette;
            overlay.Opacity = a.Opacity / 100.0;
            overlay.Invalidate();
            if (buttonForm.IsHandleCreated) PlaceButton();
            SyncAppearance();
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
            ToolStripMenuItem presets = new ToolStripMenuItem("预设");
            for (int i = 0; i < paletteNames.Length; i++) {
                int index = i;
                presets.DropDownItems.Add(paletteNames[i], null, delegate { store.Current.Palette = index; Apply(store.Current); SaveCurrent(); });
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

        private void BuildAppearance() {
            appearance = new Form { Text = "Appearance", ClientSize = new Size(330, 290), FormBorderStyle = FormBorderStyle.FixedDialog, MaximizeBox = false, MinimizeBox = false, StartPosition = FormStartPosition.CenterScreen };
            appearance.FormClosing += delegate(object sender, FormClosingEventArgs e) { if (e.CloseReason == CloseReason.UserClosing) { e.Cancel = true; appearance.Hide(); } };
            appearance.Controls.Add(MakeLabel("颜色组合", 20, 20, 100));
            paletteBox = new ComboBox { Left = 20, Top = 44, Width = 290, DropDownStyle = ComboBoxStyle.DropDownList };
            paletteBox.Items.AddRange(paletteNames);
            paletteBox.SelectedIndexChanged += delegate { if (!syncing && paletteBox.SelectedIndex >= 0) { store.Current.Palette = paletteBox.SelectedIndex; Apply(store.Current); SaveCurrent(); } };
            appearance.Controls.Add(paletteBox);
            appearance.Controls.Add(MakeLabel("宽度", 20, 91, 60));
            widthBar = new TrackBar { Left = 76, Top = 85, Width = 190, Minimum = 400, Maximum = 1600, TickFrequency = 200 };
            widthLabel = MakeLabel("", 270, 91, 58);
            appearance.Controls.Add(widthBar); appearance.Controls.Add(widthLabel);
            appearance.Controls.Add(MakeLabel("高度", 20, 145, 60));
            heightBar = new TrackBar { Left = 76, Top = 139, Width = 190, Minimum = 48, Maximum = 1000, TickFrequency = 100 };
            heightLabel = MakeLabel("", 270, 145, 58);
            appearance.Controls.Add(heightBar); appearance.Controls.Add(heightLabel);
            appearance.Controls.Add(MakeLabel("透明度", 20, 199, 60));
            opacityBar = new TrackBar { Left = 76, Top = 193, Width = 234, Minimum = 8, Maximum = 45, TickFrequency = 5 };
            appearance.Controls.Add(opacityBar);
            widthBar.ValueChanged += delegate { if (!syncing) { store.Current.Width = widthBar.Value; Apply(store.Current); SaveCurrent(); } };
            heightBar.ValueChanged += delegate { if (!syncing) { store.Current.Height = heightBar.Value; Apply(store.Current); SaveCurrent(); } };
            opacityBar.ValueChanged += delegate { if (!syncing) { store.Current.Opacity = opacityBar.Value; Apply(store.Current); SaveCurrent(); } };
            SyncAppearance();
        }

        private void SyncAppearance() {
            if (appearance == null || appearance.IsDisposed) return;
            syncing = true;
            paletteBox.SelectedIndex = store.Current.Palette;
            widthBar.Value = Math.Max(widthBar.Minimum, Math.Min(widthBar.Maximum, overlay.Width));
            heightBar.Value = store.Current.Height;
            opacityBar.Value = store.Current.Opacity;
            widthLabel.Text = overlay.Width + " px";
            heightLabel.Text = store.Current.Height + " px";
            syncing = false;
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
