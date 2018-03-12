Redis Dict 源码阅读
==================

dict 相关数据结构汇总

![](https://imgs.bwangel.me/2018-03-10-054715.png)

## dictAdd 函数调用链

函数原型: `int dictAdd(dict *d, void *key, void *val)`

函数位置: `src/dict.c:322`

dictAdd -> dictAddRaw -> _dictKeyIndex

## 渐进式 rehash

dict的负载因子(load_factor) = ht[0].used / ht[0].size

当 dict 的负载因子过大或过小的时候，Redis 需要为这个 dict 扩展或者收缩哈希表的大小，这个过程叫做 rehash，具体操作如下:

1. 设置ht[1]的size，扩展过程中size为大于ht[0].size的最小2次幂，收缩过程中size为大于ht[0].used的最小2次幂
2. 将dict.rehashidx 设置为0
3. 在增删改查的过程中，检查 dict.rehashidx 是不是不等于 -1，如果是，那么就执行 _dictRehashStep 操作，_dictRehashStep 的操作如下:

	+ 如果当前字典上的没有迭代器，执行 dictRehash 操作
	+ dictRehash 操作就是从 ht[0] 中取出值，重新计算哈希值，然后放到 ht[1] 中，并将相应哈希表的 used 减少。将 dict.rehashidx 的索引加1，在这个过程中重新计算了 key 的哈希值，所以这个过程称为 rehash
	+ 如果ht[0]中的所有元素都复制到了 ht[1]中后，Redis 会将 ht[1] 复制到 ht[0]，然后将ht[0]置为空表(即存在dictht这个结构体变量，但是里面的dictEntry指针为空，没有任何哈希表项)，同时将 dict.rehashidx 置为 -1。
	+ 同时 dictRehash 还有一个限制，每次 rehash 的时候存在一个 empty_visits 限制(empty_visits = 10 * n，n是本次 dictRehash 操作要 rehash 哈希表项的数量)。如果访问到的空的哈希表项的次数超过了 empty_visits 后，本次 rehash 操作就结束了。

+ 由于 rehash 操作不是一次性做完的，而是在字典的操作中一点一点做的，所以这个过程称作__渐进式 rehash__

+ 因为在字典的增删改查操作中执行了 rehash 操作，所以这些操作的行为也会受到影响
  + 在 dictAdd 操作中，如果当前字典正在进行 rehash，那么新加的值都会加入到 ht[1]中，这样保证ht[0]只会减少，不会增加，最终ht[0]会变成空表
  + 在 dictFind 操作中，会在 ht[0] 和 ht[1] 两个哈希表中查询对应的键
  + 在 dictDelete 操作中也回在 ht[0] 和 ht[1] 中查找对应的键
  + dictReplace 操作调用的是 dictFind 方法查找对应的键

+ 在执行 BGSAVE 和 BGREWRITEAOF 命令时，Redis 会提高执行 rehash 操作的负载因子。因为在调用这两个命令时，Redis 会为当前进程产生子进程，而很多操作系统采用了写时复制的策略，如果不执行 rehash 操作，会避免不必要的内存写入操作，从而节省一些内存。


## TODO: 字典迭代器和 rehash 有什么关系