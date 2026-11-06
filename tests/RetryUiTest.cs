using System;using System.IO;using System.Collections.Generic;using System.Reflection;using System.Windows.Forms;using CampusToggle;
class RetryUiTest {
 [STAThread] static int Main() {
  string root=Path.Combine(Path.GetDirectoryName(Application.ExecutablePath),"retry-ui-test");Directory.CreateDirectory(root);
  string config=Path.Combine(root,"connection.txt"), startup=Path.Combine(root,"startup.vbs");
  var entries=new List<Entry>{new Entry("test",@"C:\Test\rasphone.pbk")};SelectionStore.Save(config,entries[0]);File.WriteAllText(startup,"test");
  string delay=Path.Combine(root,"delay.txt"),retry=Path.Combine(root,"retry.txt");File.WriteAllText(delay,"7");if(File.Exists(retry))File.Delete(retry);
  using(var window=new Dashboard(startup,config,delegate{return entries;})) {
   var numbers=new List<NumericUpDown>();Button save=null;
   foreach(Control c in window.Controls) { if(c is NumericUpDown)numbers.Add((NumericUpDown)c); var b=c as Button;if(b!=null&&b.Text=="保存设置")save=b; }
   numbers.Sort((a,b)=>{int cmp=a.Top.CompareTo(b.Top);return cmp!=0?cmp:a.Left.CompareTo(b.Left);});
   if(numbers.Count!=3||save==null||numbers[0].Value!=7||numbers[1].Value!=3||numbers[2].Value!=5)return 1;
   numbers[0].Value=9;numbers[1].Value=4;numbers[2].Value=12;
   typeof(Control).GetMethod("OnClick",BindingFlags.Instance|BindingFlags.NonPublic).Invoke(save,new object[]{EventArgs.Empty});
   if(File.ReadAllText(delay)!="9"||File.ReadAllText(retry)!="4,12")return 2;
  }
  using(var window=new Dashboard(startup,config,delegate{return entries;})) {
   var numbers=new List<NumericUpDown>();foreach(Control c in window.Controls)if(c is NumericUpDown)numbers.Add((NumericUpDown)c);
   numbers.Sort((a,b)=>{int cmp=a.Top.CompareTo(b.Top);return cmp!=0?cmp:a.Left.CompareTo(b.Left);});
   if(numbers.Count!=3||numbers[0].Value!=9||numbers[1].Value!=4||numbers[2].Value!=12)return 3;
  }
  return 0;
 }
}