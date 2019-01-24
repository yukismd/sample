
libname mysample '/folders/myfolders/sasuser.v94/sampledata';

/* read from cvs */
data mysample.bigclass;
	infile '/folders/myfolders/sasuser.v94/sampledata/BigClass.csv' dlm=',' firstobs=2;
	input Name $ Age Sex $ Height Weight;
run;

/* create new columns */
data mysample.bigclass;
	set mysample.bigclass;
	Height_cm = height*2.54;
	Weight_kg = weight*0.4536;
	BMI = Weight_kg / (Height_cm*0.01)**2;
run;

/* ユニークID数の確認方法 */
proc sql;
	select count(distinct name) as NameCount
	from mysample.bigclass;
run;

/* summary stats */
title "カテゴリカル変数の度数";
proc freq data=mysample.bigclass;
	tables sex;
run;

title "数値変数の記述統計量";
proc means data=mysample.bigclass n mean std max p95 p75 median p25 p5 min;
	var age height_cm weight_kg bmi;
run;

/* カテゴリ変数別要約統計量 */
proc means data=MYSAMPLE.BIGCLASS chartype n mean std max q3 median q1 min;
	var Height_cm Weight_kg;
	class Sex Age;
run;

/* クロス集計 */
proc freq data=MYSAMPLE.BIGCLASS;
	tables  (Sex) * (Age) / chisq nopercent nocol nocum plots(only)=(freqplot mosaicplot);
run;

/* 相関、散布図 */
ods noproctitle;
ods graphics / imagemap=on;

title "相関、散布図";
proc corr  data=mysample.bigclass pearson spearman nosimple noprob plots=matrix(histogram);
	var age height_cm weight_kg bmi;
run;

/* 単回帰分析 */
ods noproctitle;
ods graphics / imagemap=on;

title "単回帰：Weight_kg~Height_cm";
proc reg data=mysample.bigclass alpha=0.05 plots(only)=(fitplot);
	model weight_kg = height_cm / clb;
	output out = work.temp_reg1 predicted=weight_kg_pred1;   /* 予測値をデータに保存 */
run;

/* csvへの書き出し */
proc export data=mysample.bigclass
			outfile='/folders/myfolders/sasuser.v94/sampledata/BigClass2.csv'
			dbms=csv replace;
run;


