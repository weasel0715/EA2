//+------------------------------------------------------------------+
//|                                              EAサンプル修正版    |
//|                       Copyright(C) 2025, weasel                  |
//+------------------------------------------------------------------+
#property copyright "Copyright(C) 2025 weasel"
#property version   "1.00"
#property strict

//--- パラメータ
extern double Lots      = 0.1;
extern int    Slippage  = 4;
extern bool   MM        = true;
extern double Risk      = 2;
int            Magic     = 59872465;

//--- シグナル定義
#define SIG_BUY_NUM    11
#define SIG_SELL_NUM    6
#define INDIVAL_CNT     (SIG_BUY_NUM + SIG_SELL_NUM)
#define DEBUG_CNT      36

string BuySignals[SIG_BUY_NUM] = {
    "EA買い１", "EA買い１", "EA買い１", "EA買い１", "EA化買い２", "EA化買い２",
    "EA化買い２", "EA化買い２", "買い３EA化", "売買補完買い", "買い５"
};
int    BuyBuffers[SIG_BUY_NUM] = {0,1,2,3,0,1,2,3,0,0,0};

string SellSignals[SIG_SELL_NUM] = {
    "売りⅠEA化のため", "売ⅡEA化", "売ⅡEA化", "売り３", "売買補完売り", "売り６"
};
int    SellBuffers[SIG_SELL_NUM] = {0,0,1,0,0,0};

//--- ラベル名生成
string g_labels[INDIVAL_CNT];
int    iIfchk[DEBUG_CNT];

int OnInit() {
    // チャート上にデバッグ用ラベルを作成
    for(int i = 0; i < INDIVAL_CNT; i++) {
        string label = "indival" + IntegerToString(i);
        g_labels[i] = label;
        if(ObjectFind(label) < 0) {
            ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
            ObjectSet(label, OBJPROP_CORNER, 0);
            ObjectSet(label, OBJPROP_XDISTANCE, 30);
            ObjectSet(label, OBJPROP_YDISTANCE, 20 + 17 * i);
        }
    }
    return(INIT_SUCCEEDED);
}

//--- ポジションカウント
int GetPositionCount(int type) {
    int cnt = 0;
    for(int i = 0; i < OrdersTotal(); i++) {
        if(OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber() == Magic && OrderSymbol() == Symbol()) {
            if(OrderType() == type) cnt++;
        }
    }
    return(cnt);
}

//--- 全決済
void CloseAll(int type) {
    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        if(OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber() == Magic && OrderSymbol() == Symbol()) {
            if(OrderType() == type) {
                double price = (type == OP_BUY) ? Bid : Ask;
                OrderClose(OrderTicket(), OrderLots(), price, Slippage, clrYellow);
            }
        }
    }
}

//--- MM対応ロット計算
double GetMMlots() {
    double minLots = MarketInfo(Symbol(), MODE_MINLOT);
    double maxLots = MarketInfo(Symbol(), MODE_MAXLOT);
    double lot     = Lots;
    if(MM) {
        double margin = AccountFreeMargin() * Risk * 0.01;
        lot = MathFloor((margin / MarketInfo(Symbol(), MODE_MARGINREQUIRED)) / minLots) * minLots;
        if(lot < minLots) lot = minLots;
        if(lot > maxLots) lot = maxLots;
        lot = NormalizeDouble(lot, 2);
    }
    return(lot);
}

//--- メイン処理
void OnTick() {
    double buyVals[SIG_BUY_NUM], sellVals[SIG_SELL_NUM];
    ArrayInitialize(buyVals, 0);
    ArrayInitialize(sellVals, 0);

    double lot     = GetMMlots();
    int    buyPos  = GetPositionCount(OP_BUY);
    int    sellPos = GetPositionCount(OP_SELL);
    int    res;  // ここで一度宣言

    //--- 新規買い（16ロット）
    if(sellPos == 0 && buyPos == 0) {
        res = OrderSend(Symbol(), OP_BUY, lot * 16, Ask, Slippage, 0, 0, "", Magic, 0, clrBlue);
        if(res > 0) return;
    }
    buyPos = GetPositionCount(OP_BUY);

    //--- 買いシグナル処理
    if(sellPos == 0 && buyPos < 2) {
        for(int bi = 0; bi < SIG_BUY_NUM; bi++) {
            buyVals[bi] = iCustom(NULL, 0, BuySignals[bi], BuyBuffers[bi], 5);
            if(buyVals[bi] != EMPTY_VALUE && buyVals[bi] != 0 && GetPositionCount(OP_BUY) < 2) {
                res = OrderSend(Symbol(), OP_BUY, lot * 8, Ask, Slippage, 0, 0, "", Magic, 0, clrBlue);
                if(res > 0) buyPos++;
            }
        }
    }

    //--- 新規売り（16ロット）
    if(buyPos == 0 && sellPos == 0) {
        res = OrderSend(Symbol(), OP_SELL, lot * 16, Bid, Slippage, 0, 0, "", Magic, 0, clrRed);
        if(res > 0) return;
    }
    sellPos = GetPositionCount(OP_SELL);

    //--- 売りシグナル処理
    if(buyPos == 0 && sellPos < 2) {
        for(int si = 0; si < SIG_SELL_NUM; si++) {
            sellVals[si] = iCustom(NULL, 0, SellSignals[si], SellBuffers[si], 5);
            if(sellVals[si] != EMPTY_VALUE && sellVals[si] != 0 && GetPositionCount(OP_SELL) < 2) {
                res = OrderSend(Symbol(), OP_SELL, lot * 8, Bid, Slippage, 0, 0, "", Magic, 0, clrRed);
                if(res > 0) sellPos++;
            }
        }
    }

    //--- ドテン処理（買→売）
    if(buyPos > 0) {
        for(int si = 0; si < SIG_SELL_NUM; si++) {
            sellVals[si] = iCustom(NULL, 0, SellSignals[si], SellBuffers[si], 5);
            if(sellVals[si] != EMPTY_VALUE && sellVals[si] != 0) {
                CloseAll(OP_BUY);
                OrderSend(Symbol(), OP_SELL, lot * 8, Bid, Slippage, 0, 0, "", Magic, 0, clrRed);
                break;
            }
        }
    }

    //--- ドテン処理（売→買）
    if(sellPos > 0) {
        for(int bi = 0; bi < SIG_BUY_NUM; bi++) {
            buyVals[bi] = iCustom(NULL, 0, BuySignals[bi], BuyBuffers[bi], 5);
            if(buyVals[bi] != EMPTY_VALUE && buyVals[bi] != 0) {
                CloseAll(OP_SELL);
                OrderSend(Symbol(), OP_BUY, lot * 8, Ask, Slippage, 0, 0, "", Magic, 0, clrBlue);
                break;
            }
        }
    }
}

//--- 終了時処理
void OnDeinit(const int reason) {
    if(IsTesting()) {
        string swrite = "";
        for(int i = 0; i < DEBUG_CNT; i++) {
            swrite += IntegerToString(iIfchk[i]) + ",";
        }
        int handle = FileOpen("EAEditorDebug.csv", FILE_CSV | FILE_WRITE, ',');
        if(handle > 0) {
            FileWrite(handle, swrite);
            FileClose(handle);
        }
    }
}