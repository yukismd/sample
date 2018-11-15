
######################################
### 主成分分析に関しての詳細まとめ ###
### prcomp()                       ###
### eigen()による主成分分析        ###
### svd()による主成分分析          ###
######################################

## irisデータの1,2,3,4列目を使用
df_iris <- iris[,1:4]

## デフォルトでは共分散行列から実行
res_cov <- prcomp(df_iris)

## 相関係数行列から実行
res_cor <- prcomp(df_iris, scale=TRUE)
res_cor
# Standard deviations: 固有値の平方根
# Rotation: 固有ベクトル - 主成分に対する各変数(標準化済み)の重み（係数）
#res_cor$rotationで取得

summary(res_cor)
# 固有値(の平方根)に関する情報と各主成分の寄与率

res_cor$x
# 主成分(PC)


### 主成分(PC)の計算
df_iris_s <- scale(df_iris)   # 標準化X (150×4)
egen_vec <- res_cor$rotation   # 固有ベクトル (4×4)

df_iris_s %*% egen_vec   # X*Wと行列計算
# res_cor$x に一致


### 負荷量行列の計算 - 以下2通りの計算方法
# 元データと主成分の相関 => 各主成分がどの変数と関連が高いかを把握
cor(df_iris, res_cor$x)
# 固有ベクトル×固有値の平方根（対応した主成分同士を掛け合わせる）
res_cor$rotation %*% diag(res_cor$sdev)


### バイプロット
biplot(res_cor)
# res_cor$x[,1:2]とcor(df_iris, res_cor$x)[,1:2]の重ね合わせ



### 相関係数行列に対する固有値分解による主成分分析 ###
eigen(cor(df_iris))
# res_corに一致



### 特異値分解による主成分分析 ###
# X = UDV'
res_svd <- svd(scale(df_iris/sqrt(nrow(df_iris)-1)))

## UD
res_svd$u %*% diag(res_svd$d)
# 主成分(res_cor$x)に一致

## V
res_svd$v
# 固有ベクトル(res_cor$rotation)に一致


