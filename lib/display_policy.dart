bool isNight(int hour,int start,int end) {
  if(start==end)return false;
  return start<end ? hour>=start&&hour<end : hour>=start||hour<end;
}
