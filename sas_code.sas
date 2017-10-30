                   

	                                *******************
	                                *   客户定位分析   *
	                                *******************

 
                                   *******数据预探索*****
导入数据;
proc import out=finance
      datafile="Z:\Desktop\data\fintech\bank_data.csv" dbms=csv replace;
run;
proc contents data=finance;run;
/*55个变量*/
/*数值变量*/
%let var=AGE AUM_3 AUM_6 A_L_FIANCE CHILDREN CUST_ID C_1W_D_3 C_1W_D_6 
		C_1W_TR_3 C_1W_TR_6 C_FIANCE_6 C_FIX_3 C_FIX_6 C_FUND_3 C_FUND_6 
		DEBIT_3 DEBIT_6 DEPOSIT_3 DEPOSIT_6 DOB DT_L_FINACE FINACE_3 FINACE_6 
		FIX_3 FIX_6 FUND_3 FUND_6 GAP_FIANCE_6 PAYROLL_3 PAYROLL_6 TARGET YJL_6;

/*字符变量*/
%let char=CHANNEL_PRE C_DEBIT_3 C_DEBIT_6 C_FIANCE_3 C_YJL_3 C_YJL_6 
			EDUCATION F_CC F_CLOAN F_FUND F_HLOAN F_MOBILE F_PAYROLL F_STAFF F_TEL 
			F_VIP F_WEB F_YJL F_YLJ GAP_FINACE_3 GENDER MARR YJL_3;
/*数值型--描述统计*/
proc means data=finance n nmiss mean median min max;
     var &var;
run;
/*字符型--描述统计*/
proc freq data=finance;
   table &char
	/plots(only)=freqplot;
run;

****数据存在噪音：
总观测：354293行, 但是可能存在重复观测
有很多字符变量, 需要编码
变量多：55个而且很多变量有很多缺失值
数据分布不均衡 因变量 target  0:1比例约为：34:1
很多字段 3月 6月的信息, 很可能高度共线
多变量之间量纲不统一

                               ******数据预处理****

                              *****抽取合理数据集*****

***  step1 ***  
数据为宽型数据 每行观测应该唯一 
查看是否有重复观测 并去除重复观测 , 去重后观测数 352487  重复观测：1806 行;

/*proc SQL;*/
/*    create table fin_dis as*/
/*    select distinct * from finance order by CUST_ID;*/
/*quit;*/

proc sql;
delete from finance  where CUST_ID not in (select min(CUST_ID) from finance group by _numerie_, _character_ );
run;

proc contents data=fin_dis;run;

***  step2  *** 
*根据因变量target 0 1 占比判断数据是否均衡;
proc freq data=fin_dis;
   table target
	/missing;
run;
/*0 1 占比34:1 数据不均衡抽取平衡数据集*/
data fin_1 fin_0;
   set fin_dis;
   if target=1 then output fin_1;
      else output fin_0;
run;
/*保留fin_1中所有数据 抽样使1 0占比 1:3 */
*随机抽样;
proc surveyselect data=fin_0 
        out=fin_slt_0 method=srs seed=12345  n=22228;
run;

/*合成均衡数据集*/
data fin_bal;
	set fin_slt_0 fin_1;
run;

***  step3  *** 
查看数据缺失情况 数据缺失量过多有可能是由数据不均衡导致, 要先抽取均衡数据集;
proc means data=fin_bal N Nmiss min max;
   var &var;
run;
proc freq data=fin_bal;
   table &char
	/missing;
run;
*筛除缺失占比达85%以上的变量: 55-16=39;
%let miss=C_DEBIT_3 C_DEBIT_6 C_FUND_3 C_YJL_3 C_FUND_6 YJL_3 PAYROLL_3 
C_1W_D_3 C_YJL_6 C_FIX_3 YJL_6 PAYROLL_6 EDUCATION C_1W_D_6 C_FIX_6 MARR;

/*除客户ID, 因变量TARGET外, 需要筛选的变量还有： 39-2=37  */
/*数值型变量：21 */
%let var1=C_1W_TR_3  FIX_3  FIX_6  FINACE_3  C_FIANCE_6  GAP_FIANCE_6  FINACE_6 
			C_1W_TR_6  A_L_FIANCE  DT_L_FINACE  DEPOSIT_3  DEPOSIT_6  AGE  AUM_3 
			DEBIT_3  DEBIT_6  FUND_3  AUM_6  FUND_6  CHILDREN  DOB ;

/*字符型变量: 16 */
%let char1=F_CC  F_CLOAN  F_FUND  F_HLOAN  F_MOBILE  F_PAYROLL  F_STAFF  F_TEL  F_VIP 
			F_WEB  F_YJL  F_YLJ  CHANNEL_PRE  C_FIANCE_3  GAP_FINACE_3  GENDER;

***  step4  *** 
抽取训练集 验证集;
data fin_train fin_valid;
   set fin_bal;
   ran=ranuni(12345);
   if ran<0.7 then output fin_train;
   	else output fin_valid;
   drop ran &miss;
run;

                                   *****字符转数值*****
***  step5  *** 
使用数组,循环, 对字符型变量重编码;
%macro recod(in_data,out_data);
data &out_data(drop=i);
 	set &in_data;
	array cha{*}_character_;
	do i=1 to dim(cha);
	   if cha{i}='YES' then cha{i}=1;
	      else if cha{i}='YE' then cha{i}=1;
	      else if cha{i}='NO' then cha{i}=0;
		  else if cha{i}='男性' then cha{i}=1;
		  else if cha{i}='女性' then cha{i}=0;
		  else if cha{i}='未知' then cha{i}='.';
		  else if cha{i}='柜面' then cha{i}=0;
		  else if cha{i}='网银' then cha{i}=1;
		  else if cha{i}='手机银行' then cha{i}=2;
		  else if cha{i}=' ' then cha{i}='.';
	end;
run;
%mend;

%recod(fin_train,finance_train_rec);
%recod(fin_valid,finance_valid_rec);
 

/*已将所有变量转换为数值型*/
proc contents data=train_rec;
run;
proc contents data=valid_rec;
run;
/*需要筛选的变量数 37*/
/*连续变量 23 */
%let var_list1=C_1W_TR_3  FIX_3  FIX_6  FINACE_3  C_FIANCE_6  GAP_FIANCE_6  FINACE_6 
			C_1W_TR_6  A_L_FIANCE  DT_L_FINACE  DEPOSIT_3  DEPOSIT_6  AGE  AUM_3 
			DEBIT_3  DEBIT_6 FUND_3  AUM_6  FUND_6  CHILDREN  DOB   C_FIANCE_3  GAP_FINACE_3;
/*分类变量 14 */
%let cla_list1=F_CC  F_CLOAN   F_FUND   F_HLOAN  F_MOBILE   F_PAYROLL   F_STAFF   F_TEL   F_VIP 
			 F_WEB  F_YJL  F_YLJ  CHANNEL_PRE  GENDER;


								 *********缺失值填补*********

***  step6  ***
缺失值填补;
/*连续变量 &var_list1 服从正态分布的用均值填补，偏态分布的用中位数填补*/
/*分类变量 CHANNEL_PRE 将缺失值视为一类 GENDER 用众数  */

proc means data=train_rec n nmiss mode mean median min  max std;
    var &var_list1;
run;

%macro miss(in_data,out_data);
data &out_data;
    set &in_data;
	if C_1W_TR_3=.    then  C_1W_TR_3 =1.0000000 ;
	if FIX_3=.        then  FIX_3   =70000.00 ;
	if FIX_6=.        then  FIX_6   =60000.00 ;
	if FINACE_3=.     then  FINACE_3   =74725.27 ;
	if C_FIANCE_6=.   then  C_FIANCE_6   =2.0000000 ;
	if GAP_FIANCE_6=. then  GAP_FIANCE_6  =91.0000000 ;
	if FINACE_6=.     then  FINACE_6   =69617.49 ;
	if C_1W_TR_6=.    then  C_1W_TR_6   =1.0000000 ;
	if A_L_FIANCE=.   then  A_L_FIANCE  =100000.00 ;
	if DT_L_FINACE=.  then  DT_L_FINACE  =20171.00 ;
	if DEPOSIT_3=.    then  DEPOSIT_3   =9368.34 ;
	if DEPOSIT_6=.    then  DEPOSIT_6   =10863.97 ;
	if AGE=.          then  AGE    =59.0000000 ;
	if AUM_3=.        then  AUM_3    =22193.60 ;
	if DEBIT_3=.      then  DEBIT_3  =0 ;
	if DEBIT_6=.      then  DEBIT_6   =0 ;
	if FUND_3=.       then  FUND_3     =0 ;
	if AUM_6=.        then  AUM_6     =17229.62 ;
	if FUND_6=.       then  FUND_6     =0 ;
	if CHILDREN=.     then  CHILDREN     =0 ;
	if DOB=.          then  DOB     =3425.00 ;
	if C_FIANCE_3=.   then  C_FIANCE_3    =1.0000000 ;
	if GAP_FINACE_3=. then  GAP_FINACE_3  =9.0000000 ;
	if CHANNEL_PRE=.  then CHANNEL_PRE     =3;
	if GENDER=.       then GENDER    =0;
run;
%mend;

%miss(train_rec, train_nomiss);
%miss(valid_rec, valid_nomiss);
proc means data=train_nomiss n nmiss mode mean median min  max std;
    var &var_list1 &cla_list1;
run;   
 
                            	*****异常值处理******

***  step7 ***
异常值的处理更多的是结合业务知识来判断的, 这里就只从数据分布上来判断是否异常
异常值处理 3sigma;
proc means data=train_nomiss n nmiss mode mean median min p1 p95 p99 max std;
    var &var_list1;
run;
/*根据均值加减3倍标准差原则  用 百分之99分位数, 替代异常*/
%macro normal(in_data,out_data);
data &out_data;
	set &in_data;
	C_1W_TR_3=max(min(C_1W_TR_3, 2.0000000), 1.0000000);
	FIX_3=max(min(FIX_3,  500000.00),4709.01);
	FIX_6=max(min(FIX_6, 500811.16),2837.16);
	FINACE_3=max(min(FINACE_3,701538.46),7142.86);
	C_FIANCE_6=max(min(C_FIANCE_6,23.0000000),1.0000000);
	GAP_FIANCE_6=max(min(GAP_FIANCE_6,183.0000000),7.0000000);
	FINACE_6=max(min(FINACE_6,826775.96),6885.25);
	C_1W_TR_6=max(min(C_1W_TR_6,3.0000000),1.0000000);
	A_L_FIANCE=max(min(A_L_FIANCE,1200000.00),48200.00);
	DT_L_FINACE=max(min(DT_L_FINACE,20632.00),17734.00);
	DEPOSIT_3=max(min(DEPOSIT_3,624592.67),0.1800000);
	DEPOSIT_6=max(min(DEPOSIT_6,600228.74),0.2500000);
	AGE=max(min(AGE,87.0000000),24.0000000);
	AUM_3=max(min(AUM_3,1521085.68),0);
	DEBIT_3=max(min(DEBIT_3,350000.00),0);
	DEBIT_6=max(min(DEBIT_6,266666.67),0);
	FUND_3=max(min(FUND_3,322893.50),0);
	AUM_6=max(min(AUM_6,1032059.36),0);
	FUND_6=max(min(FUND_6,228829.39),0);
	CHILDREN=max(min(CHILDREN,0),0);
	DOB=max(min(DOB,5939.00),313.0000000);
	C_FIANCE_3=max(min(C_FIANCE_3,5.0000000),1.0000000);
	GAP_FINACE_3=max(min(GAP_FINACE_3,9.0000000),1.0000000);
run;
%mend;
	
%normal(train_nomiss,train_nomal);
%normal(valid_nomiss,valid_nomal);
proc means data=train_nomal n nmiss mode mean median min p1 p99 max std;
    var &var_list1 &cla_list1;
run;


			 							*******标准化处理********

***  step8  ***
标准化数据  归一化;
/*描述统计 查看分布情况*/
proc means data=train_nomal n nmiss mean median min p1 p99 max std;
     var &var_list1;
run;
/*绘制直方图 查看分布情况*/
%macro plt(var_name);
proc sgplot data=train_nomal;
    histogram &var_name;
	density &var_name;
	density &var_name
		/type=kernel;
run;
%mend;

%plt(AUM_6);

/*对右偏的连续变量做log变换*/
%let log=FIX_3 FIX_6 FINACE_3  FINACE_6 
			 A_L_FIANCE DT_L_FINACE DEPOSIT_3 DEPOSIT_6 AGE AUM_3 
			DEBIT_3 DEBIT_6 FUND_3 AUM_6 FUND_6 DOB;
/*对右偏的计数型变量做 sqrt 变换 */
%let sqrt=C_1W_TR_3 C_FIANCE_6 C_1W_TR_6  CHILDREN C_FIANCE_3 GAP_FINACE_3 GAP_FIANCE_6; 
%macro std(in_data,out_data);
data &out_data(drop=i j);
     set &in_data;
	 array var1{*} &log;
	 array var2{*} &sqrt;
	 do i=1 to dim(var1);
	    if var1{i} not in ( .,0) then var1{i}=log10(var1{i});
	 end;
	 do j=1 to dim(var2);
	    if var2{j} ^= . then var2{j}=sqrt(var2{j});
	 end;
run;
%mend;

%std(train_nomal,train_std);
%std(valid_nomal,valid_std);
/*描述统计*/
proc means data=train_std n nmiss mode mean median min p1 p95 p99 max std;
    var &var_list1;
run;



                              ********变量筛选********

*** step9  ***
变量筛选, 需要筛选的变量数: 37;
/*由描述统计发现 变量 CHILDREN 为一常量 需要筛除  需要筛选的变量数：  36  */
/*连续变量 22 */
%let var_list1=FIX_3  FIX_6  FINACE_3  FINACE_6  C_FIANCE_3  C_FIANCE_6  GAP_FINACE_3  GAP_FIANCE_6  
			     C_1W_TR_3  C_1W_TR_6  DEPOSIT_3  DEPOSIT_6  AUM_3  AUM_6  DEBIT_3  DEBIT_6  FUND_3  FUND_6 
                 AGE  DOB  A_L_FIANCE  DT_L_FINACE;
/*分类变量 14 */
%let cla_list1=F_CC  F_CLOAN  F_FUND  F_HLOAN  F_MOBILE  F_PAYROLL  F_STAFF  F_TEL  F_VIP 
			F_WEB  F_YJL  F_YLJ  CHANNEL_PRE  GENDER;

***1 根据共线性筛除变量;
/*相关分析 corr*/
*连续与分类间相关性;
proc corr data=train_std spearman;
	var target &cla_list1;
    with &var_list1;
run;
*连续与连续间相关性;
proc corr data=train_std pearson;
	var &var_list1;
run;
*分类与分类间相关性;
%macro freq1(char1,char2);
proc freq data=train_std;
	table &char1*&char2
		/chisq;
run;
%mend;

%freq1(F_CLOAN,F_HLOAN);
/*VIF检验*/
*方差膨胀因子(Variance Inflation Factor)：
     是指解释变量之间存在多重共线性时的方差与不存在多重共线性时的方差之比。
     容忍度的倒数，VIF越大，显示共线性越严重:
     当0<VIF<10，不存在多重共线性；
	 当10≤VIF<100，存在较强的多重共线性；
     当VIF≥100，存在严重多重共线性;
proc reg data=train_std;
     model target=&var_list1 &cla_list1
	/vif;
run;
*筛除具有共线性的变量：-13 ;
%let gx=FIX_3 C_FINACE_3 C_FINACE_6 GAP_FINACE_3 DEPOSIT_3 DEPOSIT_6 
         AUM_3 DEBIT_3 DT_L_FINACE FUND_3 FUND_6 FINACE_3 C_1W_TR_3 ;
*需要筛选的变量数: 23;
/*连续变量 9 */
%let var_list2= FIX_6  FINACE_6 GAP_FIANCE_6 C_1W_TR_6  AUM_6 DEBIT_6 AGE DOB A_L_FIANCE ;
/*分类变量 14 */
%let cla_list2=F_CC F_CLOAN F_FUND F_HLOAN F_MOBILE F_PAYROLL F_STAFF F_TEL F_VIP 
			F_WEB F_YJL F_YLJ CHANNEL_PRE GENDER;

***2 多方法组合对比筛选变量;
/*1、相关分析 corr*/
*target--&var_list2;
proc corr data=train_std spearman;
	var target; 
    with &var_list2;
run;
*target--&cla_list2;
proc freq data=train_std;
	table (&cla_list2)*target
        /chisq nocol nopercent;
run;

/*3、逐步回归法筛选变量*/
proc logistic data=train_std descending namelen=50;
     model target(event='1')=&var_list2 &cla_list2
	 /selection=stepwise 
		sls=0.05  sle=0.05
		stb  lackfit  parmlabel;
run;
/*4、根据ROC曲线各变量解释信息百分比 筛选变量*/
proc logistic data=train_std plots=roc;
    class &cla_list2;
	model target(event='1')=&var_list2 &cla_list2/ctable;
    ROC  "FIX_6"         FIX_6;
	ROC  "FINACE_6"      FINACE_6;
	ROC  "GAP_FIANCE_6"  GAP_FIANCE_6;
	ROC  "C_1W_TR_6"     C_1W_TR_6;
	ROC  "AUM_6"         AUM_6;
	ROC  "DEBIT_6"       DEBIT_6;
	ROC  "AGE"           AGE;
	ROC  "DOB"           DOB;
	ROC  "A_L_FIANCE"    A_L_FIANCE;
	ROC  "F_CC"          F_CC;
	ROC  "F_CLOAN"       F_CLOAN;
	ROC  "F_FUND"        F_FUND;
	ROC  "F_HLOAN"       F_HLOAN;
	ROC  "F_MOBILE"      F_MOBILE;
	ROC  "F_PAYROLL"     F_PAYROLL;
	ROC  "F_STAFF"       F_STAFF;
	ROC  "F_TEL"         F_TEL;
	ROC  "F_VIP"         F_VIP;
	ROC  "F_WEB"         F_WEB;
	ROC  "F_YJL"         F_YJL;
	ROC  "F_YLJ"         F_YLJ;
	ROC  "CHANNEL_PRE"   CHANNEL_PRE;
	ROC  "GENDER"        GENDER;
run;

*根据以上 相关系数 逐步回归 ROC这三种筛选结果对比
选出共同认为重要的变量, 对有异议的变量依次放入模型查看模型精度是否有显著变化，有则进，否则剔除;
ods graphics on;
proc logistic data=train_std plots(MAXPOINTS=5000)=roc;
  class &cla_list2;
  model target(event='1')=&var1;
run;
ods graphics off;

/*AUM值也就是资产管理规模，是指衡量金融机构资产管理业务规模的指标，是该银行当前管理客户资产的总市值。*/

/*精度80.74%*/
%let var2=AUM_6  CHANNEL_PRE  F_WEB  DOB  AGE  GAP_FIANCE_6  GENDER ;     
 
*确定最终模型中的变量为: 7;
%let var2=AUM_6  CHANNEL_PRE  AGE  GAP_FIANCE_6  F_WEB  DOB  GENDER;


                                   *****模型建立******

***  step10  ***
模型的建立与评估;
/*用训练集建立模型 并结合验证集 诊断 修正 评估*/
*ROC曲线诊断 ;
ods graphics on;
proc logistic data=train_std outmodel=fin_model plots(MAXPOINTS=5000)=roc;
	 class CHANNEL_PRE F_WEB GENDER;
	 model target(event='1')=&var2
		/pprob=0.33 ctable;
	 score out=train_score;
run;
proc logistic data=valid_std plots(MAXPOINTS=5000)=roc;
    class CHANNEL_PRE F_WEB GENDER;
	model target(event='1')=&var2;
run;
ods graphics off;

/*调用模型 用验证集进行模型诊断 评估*/
proc logistic inmodel=fin_model;
    score data=valid_std out=valid_score
	 priorevent=0.33;      *以先验概率设置预测结果中target=1的占比可调节;
run;
/*训练集和验证集 预测结果二分类表作对比*/
%macro f_i(data);
proc freq data=&data;
   table f_target*i_target;
run;
%mend;
%f_i(train_score);
%f_i(valid_score);

 
 
                                ****模型解释****

***  step11  ***
模型没问题后;
/*1、保存模型根据最大似然估计分析表 确定各变量系数,将模型具体化*/
proc logistic data=train_std outmodel=fin_model;
	 class CHANNEL_PRE F_WEB GENDER;
	 model target(event='1')=&var2;
run;

/*2、对模型做出解释*/
/*调用模型 对验证集得分评价 根据业务需求 以先验概率为基础 合理灵活的调整判断客户是否响应的阈值*/
proc logistic inmodel=fin_model;
     score data=valid_std out=valid_score
	 priorevent=0.33;         
run;
proc freq data=valid_score;
	table f_target*i_target;
run;
*先验概率 priorevent 为原始数据集（按均衡比例抽取出的均衡数据集）中 事件 target=1 的占比
可根据具体业务 公司情况 以先验概率为基础 调节阈值（这儿的阈值指的是预测结果中 target=1 的占比）
若 需扩大业务 扩张客户量 可调高该阈值，反之降低;

/*3、具体化解释模型结构中各变量对模型预测结果的影响*/
*连续变量可直接通过正负相关性解释相应的影响，也可以将部分连续变量 如：age 离散化之后更易于解释，
分类变量可通过分析对比各分类水平上target=1和0 的占比 进一步解释哪一类水平的客户更可能响应或不响应，
也可以对分类变量做哑变量变换，将每一类视为一个独立的变量，进而比较各类哑变量对模型的贡献度;

/*探究分类变量中哪一类更有可能购买该理财产品*/
proc freq data=train_std;
    table target*(CHANNEL_PRE gender F_WEB )/chisq;
run;
/*为了更易于解释连续变量对模型的影响，对部分连续变量（做离散化处理，探究随着连续变量的变化，响应概率的变化趋势）*/
%macro lift_var(in_data,Var_group,n_group);
proc sort data=&in_data out=fin_sort;
   by &var_group;
run;
*添加分组列 一般设置 10组;
data fin_group;
   set fin_sort;
   group=ceil(_N_/&n_group);
run;
*根据分组 求出每组的p值   p值=每组中实际target为1的占比除以整个数据集中target为1的占比;
data fin_plt_lift;
    set fin_group;
	by group;
	if first.group then sum=0;
	sum + target;
	avg=sum/&n_group;
	if last.group;
run;
*绘制lift图;
proc sgplot data=fin_plt_lift;
    series x=group y=avg/markers;
run;
%mend;
%let var2=AUM_6 CHANNEL_PRE F_WEB DOB AGE GAP_FIANCE_6 GENDER ;
%lift_var(train_std,age,4628);  %lift_var(valid_std,age,2042);
%lift_var(train_std,DOB,4628);  %lift_var(valid_std,DOB,2042); 
%lift_var(train_std,GAP_FIANCE_6,4628);  %lift_var(valid_std,GAP_FIANCE_6,2042); 
%lift_var(train_std,AUM_6,4628);  %lift_var(valid_std,AUM_6,2042); 
