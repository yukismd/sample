/* AIJC Day5 Exercise by SAS */

libname mysample '/folders/myfolders/sasuser.v94/sampledata';

proc import out=ec_tran
	datafile='/folders/myfolders/sasuser.v94/sampledata/ec_trans_mod.csv' dbms=csv replace;
	getnames=yes;
	datarow=2;
	GUESSINGROWS=500;  /* 指定された範囲内のデータから、変数，データ型，データ長を判断 */
                       /* 型指定で読み込む必要あり。invoicenoが数値と認識され、文字を含むデータが削除される */
run;

proc print data=ec_tran(obs=1000);
run;

proc contents data=ec_tran;
run;


********** 2. データ確認とクレンジング **********;

** (2.1) 生データのStockCodeを全て大文字に変換したカラムを作成し、名称をStockCodeとする;
/* 文字変数をupper caseに変換 */
data ec_tran;
	set ec_tran;
	StockCode = upcase(stockcode);
run;

** (2.1) 大文字変換されたStockCodeの左5桁を、StockCode2というカラムとする;
data ec_tran;
	set ec_tran;
	StockCode2 = substr(stockcode,1,5);
run;

** (2.2) 受領したデータの取引期間（InvocieDateの最小値と最大値）を確認せよ。;
proc means data=WORK.EC_TRAN chartype mean std min max n vardef=df;
	var InvoiceDate;
	output out=work.Means_stats mean=std=min=max=n= / autoname;           /* 出力したデータテーブル上で確認 */
run;
/* Min: 01DEC10:08:26:00,  Mean: 04JUL11:13:34:57,  Max: 09DEC11:12:50:00 */


** (2.3) CustomerIDが非NULLのデータを対象に、データ件数、CustomerIDのユニーク件数、InvoiceNoのユニーク件数を確認せよ。;
proc sql;    /* nullの行数 */
	select count(*) as n_null
	from ec_tran
	where customerid is null;
quit;
/* 135,080 */

proc sql;
	select count(*) as n_not_null, count(distinct customerid) as unq_customer, count(distinct invoiceno) as unq_invoice
	from ec_tran
	where customerid is not null;
quit;


** (2.4) CustomerIDが非NULLのデータを対象に、購買数量（Quantity）と単価（UnitPrice）の最小値・平均値・最大値を確認せよ。;
proc sql;
	select count(*) as n_not_null, 
	min(quantity) as min_quantity, avg(quantity) as avg_quantity, max(quantity) as max_quantity,
	min(unitprice) as min_unitprice, avg(unitprice) as avg_unitprice, max(unitprice) as max_unitprice
	from ec_tran
	where customerid is not null;
quit;


** (2.5) 購買数量（Quantity）が負となるケースは注文のキャンセルで生じることがわかった。キャンセルはInvocieNoが"C"で始まるという。;
** CustomerIDが非Nullのデータを対象に、以下2つのケースについて数値確認せよ。;
**		1.nvoiceNoが"C"始まりのときの、Qunatityの最小値・平均値・最大値;
**		2.InvoiceNoが"C"始まりでないときの、Qunatityの最小値・平均値・最大値;

/* CustomerIDが非Nullのデータを"ec_tran_cust"として作成 */
proc sql;
	create table ec_tran_cust as
	select *
	from ec_tran where customerid is not null;
quit;

/* cancel flagの追加 */
data ec_tran_cust;
	set ec_tran_cust;
	if substr(invoiceno, 1, 1)='C' then Cancel=1;
	else Cancel=0;
run;

proc print data=ec_tran_cust(obs=300);
run;

title "キャンセル";
proc sql;
	select min(quantity) as min, avg(quantity) as avg, max(quantity) as max
	from ec_tran_cust where cancel=1;
quit;
title "非キャンセル";
proc sql;
	select min(quantity) as min, avg(quantity) as avg, max(quantity) as max
	from ec_tran_cust where cancel=0;
quit;
title;


** (2.6) CustomerIDが非NULLのデータを対象に、単価（UnitPrice）がゼロのデータ件数を確認せよ。;
proc sql;
	select count(*) as unitprice_0
	from ec_tran_cust where unitprice=0;
quit;


********** 3. 予測用データマート設計に関する集計 **********;

** (3.1) 2011年1月から6月末までの半年間のデータを対象に、購買回数4回以上の顧客層と4回未満の顧客層それぞれについて、;
**       顧客数、購買金額(Quantity*Unitprice)、購買回数を集計せよ。;
**       ただし集計はCustomerIDが非NULL、UnitPriceが正のデータを対象に行うこと。;

/* CustomerIDが非NULLかつ、UnitPrice > 0 のデータを"ec_tran_cust_prc"として作成 */
proc sql;
	create table ec_tran_cust_prc as
	select * 
	from ec_tran_cust where unitprice>0;
quit;

/* 購買回数顧客リスト（2011年1月から6月末）の対象者フラグ"bw_2011_1n6"の作成 */
data ec_tran_cust_prc;
	set ec_tran_cust_prc;
	if invoicedate>=DHMS(MDY(1,1,2011), 0, 0, 0) and invoicedate<DHMS(MDY(7,1,2011), 0, 0, 0) then bw_2011_1n6=1;
	else bw_2011_1n6=0;
run;
** bw_2011_1n6 = 0: 256,760;
**             = 1: 150,029;

/* 1行1顧客集計データ"customer1"の作成 */
proc sql;
	create table customer1 as
	select customerid, count(*) as n, 
	count(distinct invoiceno) as trip,
	sum(quantity) as ttl_quantity, 
	avg(unitprice) as avg_price,
	sum(quantity*unitprice) as ttl_amount
	from ec_tran_cust_prc where bw_2011_1n6=1
	group by customerid;
quit;

/* trip 4以上データ"customer1_more4"の作成 */
proc sql;
	create table customer1_more4 as
	select *
	from customer1 where trip>=4;
quit;
/* trip 4未満データ"customer1_less4"の作成 */
proc sql;
	create table customer1_less4 as
	select *
	from customer1 where trip<4;
quit;

/* customer1_more4とcustomer1_less4の集計 */
title "trip 4以上";
proc sql;
	select count(*), sum(ttl_amount) as ttl_amount, sum(trip) as ttl_trip
	from customer1_more4;
quit;

title "trip 4未満";
proc sql;
	select count(*), sum(ttl_amount) as ttl_amount, sum(trip) as ttl_trip
	from customer1_less4;
quit;
title;


** (3.2) 2010年12月1日～2011年5月末日の6か月間における優良顧客（購買回数4回以上の顧客）のうち、;
**       2011年6月1日～2011年8月末日までの3ヵ月間に購買が1回以上ある人数（リピート人数）を集計せよ。;
**       同様に、全顧客（購買回数1回以上）についてもリピート人数を集計せよ。;
**       ただし集計はCustomerIDが非NULL、UnitPriceが正のデータを対象に行うこと  => ec_tran_cust_prc;

/* 2010年12月1日～2011年5月末日フラグ"bw_201012_201105" */
/* 2011年6月1日～2011年8月末日フラグ"bw_201106_201108" */
data ec_tran_cust_prc;
	set ec_tran_cust_prc;
	if invoicedate>=DHMS(MDY(12,1,2010),0,0,0) and invoicedate<DHMS(MDY(6,1,2011),0,0,0) then bw_201012_201105=1;
	else bw_201012_201105=0;
	if invoicedate>=DHMS(MDY(6,1,2011),0,0,0) and invoicedate<DHMS(MDY(9,1,2011),0,0,0) then bw_201106_201108=1;
	else bw_201106_201108=0;
run;

/* 2010年12月1日～2011年5月末日における、1行1顧客集計データ"customer2"の作成 */
proc sql;
	create table customer2 as
	select customerid, count(*) as n, 
	count(distinct invoiceno) as trip,
	sum(quantity) as ttl_quantity, 
	avg(unitprice) as avg_price,
	sum(quantity*unitprice) as ttl_amount
	from ec_tran_cust_prc where bw_201012_201105=1
	group by customerid;
quit;

/* trip 4以上データ"customer2_more4"の作成 */
proc sql;
	create table customer2_more4 as
	select *
	from customer2 where trip>=4;
quit;

/* 「2010年12月1日～2011年5月末日に購買あり」and「2011年6月1日～2011年8月末日に購買あり」のtranデータ "ec_tran_cust_prc_target" */
proc sql;
	create table ec_tran_cust_prc_target as 
	select b.*
	from customer2 as a 
	left join ec_tran_cust_prc as b on a.customerid=b.customerid
	where b.bw_201106_201108=1;
quit;

/* ec_tran_cust_prc_targetにおけるユニークcustomerid数（2010年12月1日～2011年5月末日に購買あり、リピート顧客全体） */
proc sql;
	select count(distinct customerid) as all_repeat
	from ec_tran_cust_prc_target;
quit;
/* 1400 */

/* 「2010年12月1日～2011年5月末日に購買あり、かつ4回以上」and「2011年6月1日～2011年8月末日に購買あり」のtranデータ "ec_tran_cust_prc_target_more4" */
proc sql;
	create table ec_tran_cust_prc_target_more4 as 
	select b.*
	from customer2_more4 as a 
	left join ec_tran_cust_prc as b on a.customerid=b.customerid
	where b.bw_201106_201108=1;
quit;

/* ec_tran_cust_prc_targetにおけるユニークcustomerid数（2010年12月1日～2011年5月末日に購買あり、リピート顧客全体） */
proc sql;
	select count(distinct customerid) as more4_repeat
	from ec_tran_cust_prc_target_more4;
quit;
/* 580 */


** (3.3) StockCode2別の購買回数を集計し降順に表示;
**       集計期間は2010年12月1日～2011年11月末日の1年間とする。;
**       ただし集計はCustomerIDが非NULL、UnitPriceが正のレコードを対象とすること。;

/* 2010年12月1日～2011年11月末日フラグ"bw_201012_201111" */
data ec_tran_cust_prc;
	set ec_tran_cust_prc;
	if invoicedate>=DHMS(MDY(12,1,2010),0,0,0) and invoicedate<DHMS(MDY(12,1,2011),0,0,0) then bw_201012_201111=1;
	else bw_201012_201111=0;
run;

/* ec_tran_cust_prcのStockCode2で度数集計 */
proc sort data=EC_TRAN_CUST_PRC out=SortTempTableSorted;
	by bw_201012_201111;
run;
proc freq data=SortTempTableSorted;
	tables StockCode2 / nocum missprint plots=none OUT=freqOut1 OUTCUM; /* OUT=freqOut1 OUTCUMで、データも出力 */
	by bw_201012_201111;
run;
proc delete data=SortTempTableSorted;
run;
/* ライブラリ内のデータを右クリックし、エクスポート */

/* ec_tran_cust_prcを保存しておく */
data mysample.ec_tran_cust_prc;
	set ec_tran_cust_prc;
run;



********** 4. データマートの作成と予測モデルの構築評価 **********;

** (4.1) モデル用データマート作成用のクエリを完成させ、CSVファイルで出力せよ。;
**       （Documents\37_Lecture\Lecture_ML2\exercise\講師用\03_output\作業用_講師用.xlsx）
**       作業用エクセルのシート「設計」で、各データマートの特徴量計算期間、正解ラベルの定義期間を確認せよ。;
**       作業用エクセルのシート「特徴量」で、特徴量定義を確認せよ。;
**       CSVの最初の列をCustomerID、最終の列を正解ラベルとして出力せよ。;
/*
モデル用DM
	特徴量期間：2011/1-6
	ターゲット期間：2011/7-9
テスト用DM
	特徴量期間：2011/4-9
	ターゲット期間：2011/10-12
*/
/* 各フラグの作成 */
/* モデリング基準日も作成しておく（モデルDM：2011-07-01、テストDM：2011-10-01） */
data ec_tran_cust_prc;
	set mysample.ec_tran_cust_prc;
	if invoicedate>=DHMS(MDY(1,1,2011),0,0,0) and invoicedate<DHMS(MDY(7,1,2011),0,0,0) then t_model_feature=1;
	else t_model_feature=0;
	if invoicedate>=DHMS(MDY(7,1,2011),0,0,0) and invoicedate<DHMS(MDY(10,1,2011),0,0,0) then t_model_tgt=1;
	else t_model_tgt=0;
	if invoicedate>=DHMS(MDY(4,1,2011),0,0,0) and invoicedate<DHMS(MDY(10,1,2011),0,0,0) then t_test_feature=1;
	else t_test_feature=0;
	if invoicedate>=DHMS(MDY(10,1,2011),0,0,0) and invoicedate<DHMS(MDY(1,1,2012),0,0,0) then t_test_tgt=1;
	else t_test_tgt=0;
	
	format model_modeldate datetime. test_modeldate datetime.;
	model_modeldate=DHMS(MDY(7,1,2011),0,0,0);
	test_modeldate=DHMS(MDY(10,1,2011),0,0,0);
run;


/* モデルDM、特徴量用tran "ec_tran_cust_prc_model_feat" */
proc sql;
	create table ec_tran_cust_prc_model_feat as
	select * 
	from ec_tran_cust_prc where t_model_feature=1;
quit;

proc sql;
	create table model_dm as
	select customerid, 
		count(distinct invoiceno) as trips, 
		sum(quantity*unitprice) as amount_of_yen,
		sum(quantity) as quantity,
		(max(InvoiceDate)-min(InvoiceDate))/(60*60*24) as purchase_period,
		(avg(model_modeldate)-max(InvoiceDate))/(60*60*24) as purchase_recency,
		sum(quantity*unitprice) / count(distinct invoiceno) as amount_of_yen_per_trips,
		((max(InvoiceDate)-min(InvoiceDate))/(60*60*24))/count(distinct invoiceno) as regularity,
		sum(cancel) as cancellation,
		count(distinct case when cancel=1 then InvoiceNo else "" end)	as trips_cancellation,
		count(distinct case when StockCode2='85099' then InvoiceNo else "" end) as trips_cat85099,
		count(distinct case when stockcode2='85123' then invoiceno else "" end) as trips_cat85123,
		count(distinct case when stockcode2='22423' then invoiceno else "" end) as trips_cat22423,
		count(distinct case when StockCode2='47566' then InvoiceNo else "" end)	as trips_cat47566,
		count(distinct case when StockCode2='84879' then InvoiceNo else "" end)	as trips_cat84879,
		count(distinct case when StockCode2='20725' then InvoiceNo else "" end)	as trips_cat20725,
		count(distinct case when StockCode2='22720' then InvoiceNo else "" end)	as trips_cat22720,
		count(distinct case when StockCode2='POST' then InvoiceNo else "" end)	as trips_catPOST,
		count(distinct case when StockCode2='23203' then InvoiceNo else "" end)	as trips_cat23203,
		count(distinct case when StockCode2='22383' then InvoiceNo else "" end)	as trips_cat22383
	from ec_tran_cust_prc_model_feat group by customerid;
quit;

/* 各顧客における、StockCode2の最頻購買カテゴリ */
/* 縦持ち集計表を作り、度数でソート */
proc sql;
	create table tmp as
	select customerid, stockcode2, count(*) as count
	from ec_tran_cust_prc_model_feat group by customerid, stockcode2
	order by customerid, count;
quit;
/* 顧客内先頭、最終データフラグを作成 */
data tmp;
	set tmp;
	by customerid;
	first=first.customerid;
	last=last.customerid;
run;
/* 最終データのみを取得 */
proc sql;
	create table model_dm_scmode as
	select customerid, stockcode2 as mode_category
	from tmp where last=1;
quit;

/* model_dmとmodel_dm_scmodeをJOIN */
proc sql;
	create table model_dm2 as
	select a.*, b.mode_category
	from model_dm as a
	left join model_dm_scmode as b on a.customerid=b.customerid;
quit;


/* モデルDM、ターゲット用tran "ec_tran_cust_prc_model_tgt" */
proc sql;
	create table ec_tran_cust_prc_model_tgt as
	select * 
	from ec_tran_cust_prc where t_model_tgt=1;
quit;

/* ターゲット用tranに存在する顧客にtgt=0を立てる */
proc sql;
	create table model_dm_tgt as
	select distinct customerid
	from ec_tran_cust_prc_model_tgt;
quit;
data model_dm_tgt;
	set model_dm_tgt;
	tgt=0;
run;

/* model_dm2とmodel_dm_tgtをJOIN */
proc sql;
	create table model_dm3 as
	select a.*, b.tgt
	from model_dm2 as a
	left join model_dm_tgt as b on a.customerid=b.customerid;
quit;

/* null"."を1で埋める */
data model_dm3;
	set model_dm3;
	if tgt=. then tgt=1;
run;

proc sql;
	select tgt, count(*)
	from model_dm3 group by tgt;
quit;
/* 0:1481, 1:1271 */


/* モデリング対象者のtrips>=4を抽出 */
proc sql;
	create table model_dm_final as
	select *
	from model_dm3 where trips>=4;
quit;
/* 717行 */

proc sql;
	select tgt, count(*)
	from model_dm_final group by tgt;
quit;
/* 0:595, 1:122 */


******** テストDMも作成できるよう、コードをマクロ化;
******** aijc_ex1_4macro.sas;



********** 5. フォーワード検証 **********;

** (5) GBC_001_dm_for_fwd_with_pred.csvにおいて、スコアを降順に10分割し、当該ランクごとに以下を出力;
**     - スコアランク;
**     - 予測スコアの最小値, 平均値, 最大値;
**     - レコード数[A];
**     - ターゲット（正例）数[B];
**     - ターゲット（正例）含有率（[B]/[A]);

proc import out=fwd_pred
	datafile='/folders/myfolders/sasuser.v94/sampledata/GBC_001_dm_for_fwd_with_pred.csv' dbms=csv replace;
	getnames=yes;
	datarow=2;
	GUESSINGROWS=500;
run;

/* テストDMの読み込み */
proc import out=test_dm
	datafile='/folders/myfolders/sasuser.v94/sampledata/dm_for_fwd.csv' dbms=csv replace;
	getnames=yes;
	datarow=2;
	GUESSINGROWS=500;
run;

/* JOINし、予測値でソートしておく */
proc sql;
	create table test_dm_res as
	select a.*, b.pred_score
	from test_dm as a left join fwd_pred as b on a.customerid=b.customerid
	order by b.pred_score desc;
quit;

/* Binを作成 */
/* test_dm_resの行数をnobsに取得 */
proc sql noprint;
  select count(*) into :nobs trimmed
  from test_dm_res;
quit;
%put &nobs;

data test_dm_res;
	set test_dm_res;
	pred_score_rank = _n_;
	decil_rank = floor(_n_/&nobs*10);    /* 0~9のBin */
run;

/*
proc print data=test_dm_res; run;
*/

/* 集計 */
proc sql;
	select decil_rank, count(*) as count, 
	min(pred_score) as min_pred, avg(pred_score) as avg_pred, max(pred_score) as max_pred,
	sum(tgt) as n_tgt1, sum(tgt)/count(*) as precision
	from test_dm_res
	group by decil_rank;
quit;

/* test_dm_resを保存しておく */
data mysample.test_dm_res;
	set test_dm_res;
run;



********** 6. スコア上位者プロファイル（クラスタリング学習後に実施） **********;
** (6) クライアントからスコアランク上位20％相当の顧客の特徴を知りたいと要望があった。;
**     上位20%とその他顧客層の違い、及び上位20%内部の購買パターン分析;

/* 上位20%データ */
proc sql;
	create table dm_clst as
	select *
	from mysample.test_dm_res where decil_rank in (0,1);
quit;

/* trips, amount_of_yen, regularityでクラスタリング */
** 変数の標準化;
proc stdize data=WORK.DM_CLST out=Work._std_ method=std;
	var trips amount_of_yen regularity;
run;
** kmeansの実行（k=3）;
proc fastclus data=Work._std_ maxclusters=3 maxiter=5 out=work.Fastclus_scores 
		outstat=work.Fastclus_stats outseed=work.Fastclus_seeds;
	var trips amount_of_yen regularity;
run;
** FASTCLUS_SCORES : クラスターラベル;
** Fastclus_seeds : クラスター中心;
proc delete data=Work._std_;
run;

/* dm_clstへ、FASTCLUS_SCORESのclusterとdistanceを結合 */
proc sql;
	create table dm_clst_res as
	select a.*, b.cluster, b.distance
	from dm_clst as a left join fastclus_scores as b on a.customerid=b.customerid;
quit;

/* 集計 */
proc sql;
	select cluster, count(*) as count, 
	avg(trips) as avg_trip, avg(amount_of_yen) as avg_amount_of_yen, 
	avg(regularity) as avg_regularity, avg(pred_score) as avg_pred_score
	from dm_clst_res group by cluster;
quit;




*****************************************************************************************;

/* 変数の作成（numeric -> char） */
data ec_tran2;
	set ec_tran;
	invoiceno_c = put(invoiceno, 8.);
	/* char->numericの場合はinput関数 */
run;

/* ユニークID水準の確認 */
proc sql;
	select count(*) as n_low,
	count(distinct invoiceno_c) as invoice,
	count(distinct stockcode) as stock,
	count(distinct invoiceno_c||stockcode) as invoice_stock    /* invoiceとstockの掛け合わせ */
	from ec_tran2;
run;

*******************;

proc sql;
	select *
	from ec_tran_cust_prc where invoicedate>'09DEC11:12:00:00';
quit;

data ec_tran_cust_prc2;
	set ec_tran_cust_prc;
	invoicedate_row = invoicedate;
	**DayStart = mdy(1,1,2011);
	**DayEnd = mdy(7,1,2011);
	DayStart = DHMS(MDY(1,1,2011), 0, 0 , 0);
	DayEnd = DHMS(MDY(6,1,2011), 0, 0 , 0);
run;

data ec_tran_cust_prc2;
	set ec_tran_cust_prc2;
	if invoicedate >= DayStart then flg1=1;
	if invoicedate < DayEnd then flg2=1;
run;


