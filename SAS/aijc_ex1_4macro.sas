
********** 4. データマートの作成と予測モデルの構築評価 **********;
********** のマクロ化（モデル用、テスト用両方の作成のため）**********;

** (4.1) モデル用データマート作成用のクエリを完成させ、CSVファイルで出力せよ。;
**       （Documents\37_Lecture\Lecture_ML2\exercise\講師用\03_output\作業用_講師用.xlsx）
**       作業用エクセルのシート「設計」で、各データマートの特徴量計算期間、正解ラベルの定義期間を確認せよ。;
**       作業用エクセルのシート「特徴量」で、特徴量定義を確認せよ。;
**       CSVの最初の列をCustomerID、最終の列を正解ラベルとして出力せよ。;

libname mysample '/folders/myfolders/sasuser.v94/sampledata';

options symbolgen;


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

******************************************************;
/* tranデータフィルタリング */
**%let flag_flt = t_model_feature;
%let flag_flt = t_test_feature;
/* target tranデータフィルタリング */
**%let flag_tgt = t_model_tgt;
%let flag_tgt = t_test_tgt;

/* モデリング基準日 */
**%let modeldate = model_modeldate;
%let modeldate = test_modeldate;

/* 最終データセット名 */
**%let final_name = final_model_dm;
%let final_name = final_test_dm;

%put &flag_flt;
%put &sysdate9;
******************************************************;

/* モデル/テストDM、特徴量用tran "df_tran" */
proc sql;
	create table df_tran as
	select * 
	from ec_tran_cust_prc where &flag_flt=1;                             **;
quit;

proc sql;                                                                **;
	create table model_dm as
	select customerid, 
		count(distinct invoiceno) as trips, 
		sum(quantity*unitprice) as amount_of_yen,
		sum(quantity) as quantity,
		(max(InvoiceDate)-min(InvoiceDate))/(60*60*24) as purchase_period,
		(avg(&modeldate)-max(InvoiceDate))/(60*60*24) as purchase_recency,
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
	from df_tran group by customerid;
quit;

/* 各顧客における、StockCode2の最頻購買カテゴリ */
/* 縦持ち集計表を作り、度数でソート */
proc sql;
	create table tmp as
	select customerid, stockcode2, count(*) as count
	from df_tran group by customerid, stockcode2
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


/* モデルDM、ターゲット用tran "df_tgt" */
proc sql;
	create table df_tgt as
	select * 
	from ec_tran_cust_prc where &flag_tgt=1;                                    **;
quit;

/* ターゲット用tranに存在する顧客にtgt=0を立てる */
proc sql;
	create table dm_tgt as
	select distinct customerid
	from df_tgt;
quit;
data dm_tgt;
	set dm_tgt;
	tgt=0;
run;

/* model_dm2とmodel_dm_tgtをJOIN */
proc sql;
	create table model_dm3 as
	select a.*, b.tgt
	from model_dm2 as a
	left join dm_tgt as b on a.customerid=b.customerid;
quit;

/* null"."を1で埋める */
data model_dm3;
	set model_dm3;
	if tgt=. then tgt=1;
run;

/*
proc sql;
	select tgt, count(*)
	from model_dm3 group by tgt;
quit;
*/

/* モデリング対象者のtrips>=4を抽出 */
proc sql;
	create table model_dm_final as
	select *
	from model_dm3 where trips>=4;
quit;

data &final_name;
	set model_dm_final;                               **;
run;

options nosymbolgen;





*********************** 確認 ;

proc sql;
	select tgt, count(*)
	from &final_name group by tgt;
quit;
/* モデル  (717) 0:595, 1:122 */
/* テスト  (807) 0:671, 1:136 */



