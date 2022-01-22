/*
	BBandReentry.mq4
	
	Copyright 2013-2020, Orchard Forex
	https://orchardforex.com
	
	*/

#property copyright "Copyright 2013-2020, Orchard Forex"
#property link      "https://orchardforex.com"
#property version   "1.00"
#property strict

//	Inputs
//
//	Bands
//
input	int						InpBandsPeriods		=	20;				//	Bands periods
input	double					InpBandsDeviations	=	2.0;				//	Bands deviations
input	ENUM_APPLIED_PRICE	InpBandsAppliedPrice	=	PRICE_CLOSE;	//	Bands applied price

//
//	TPSL
//	
input	double					InpTPDeviations		=	1.0;				//	Take profit deviations
input	double					InpSLDeviations		=	1.0;				//	Stop loss deviations

//
//	Standard inputs
//
input	double					InpVolume				=	0.01;				//	Lot size
input	int						InpMagicNumber			=	202020;			//	Magic number
input	string					InpTradeComment		=	__FILE__;		//	Trade comment

int OnInit() {

	return(INIT_SUCCEEDED);
	
}

void OnDeinit(const int reason) {

}

void OnTick() {

	if (!IsNewBar())	return;
	
	double	close1	=	iClose(Symbol(), Period(), 1);
	double	high1		=	iHigh(Symbol(), Period(), 1);
	double	low1		=	iLow(Symbol(), Period(), 1);
	//									symbol,    timeframe, periods,        deviations,        shift,
	// 									app price,            mode,      shift
	double	upper1	=	iBands(Symbol(), Period(), InpBandsPeriods, InpBandsDeviations, 0,
											InpBandsAppliedPrice, MODE_UPPER, 1);
	double	lower1	=	iBands(Symbol(), Period(), InpBandsPeriods, InpBandsDeviations, 0,
											InpBandsAppliedPrice, MODE_LOWER, 1);

	double	close2	=	iClose(Symbol(), Period(), 2);
	double	upper2	=	iBands(Symbol(), Period(), InpBandsPeriods, InpBandsDeviations, 0,
											InpBandsAppliedPrice, MODE_UPPER, 2);
	double	lower2	=	iBands(Symbol(), Period(), InpBandsPeriods, InpBandsDeviations, 0,
											InpBandsAppliedPrice, MODE_LOWER, 2);

	if (close2>upper2 && close1<upper1) {	//	reentry from above = sell
		OpenOrder(ORDER_TYPE_SELL_STOP, low1, (upper1-lower1));
	}
	
	if (close2<lower2 && close1>lower1) {	//	reentry from below = buy
		OpenOrder(ORDER_TYPE_BUY_STOP, high1, (upper1-lower1));
	}
	
}

bool	IsNewBar() {

	//	Open time for the current bar
	datetime				currentBarTime	=	iTime(Symbol(), Period(), 0);
	//	Initialise on first use
	static datetime	prevBarTime		=	currentBarTime;
	
	if (prevBarTime<currentBarTime) {		//	New bar opened
		prevBarTime	=	currentBarTime;		//	Update prev time before exit
		return(true);
	}
	
	return(false);
	
}

int	OpenOrder(ENUM_ORDER_TYPE orderType, double entryPrice, double channelWidth) {

	//	Size of one deviation
	double	deviation	=	channelWidth/(2*InpBandsDeviations);
	double	tp				=	deviation * InpTPDeviations;
	double	sl				=	deviation * InpSLDeviations;
	datetime	expiration	=	iTime(Symbol(), Period(), 0)+PeriodSeconds()-1;
	
	entryPrice				=	NormalizeDouble(entryPrice, Digits());
	double	tpPrice		=	0.0;
	double	slPrice		=	0.0;
	double	price			=	0.0;

   double   stopsLevel  =  Point()*SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);

	if (orderType%2==ORDER_TYPE_BUY) {	//	Buy, buystop
		price					=	Ask;
		if (price>=(entryPrice-stopsLevel) ) {
			entryPrice	=	price;
			orderType	=	ORDER_TYPE_BUY;
		}
		tpPrice				=	NormalizeDouble(entryPrice+tp, Digits());
		slPrice				=	NormalizeDouble(entryPrice-sl, Digits());
	} else
	if (orderType%2==ORDER_TYPE_SELL) {	//	Sell, sellstop
		price					=	Bid;
		if (price<=(entryPrice+stopsLevel) ) {
			entryPrice	=	price;
			orderType	=	ORDER_TYPE_SELL;
		}
		tpPrice				=	NormalizeDouble(entryPrice-tp, Digits());
		slPrice				=	NormalizeDouble(entryPrice+sl, Digits());
	} else {
		return(0);
	}
	
	return(OrderSend(Symbol(), orderType, InpVolume, entryPrice, 0, slPrice, tpPrice,
							InpTradeComment, InpMagicNumber, expiration));
		
}