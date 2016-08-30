# ycsb2graph

支持将ycsb的测试结果，自动生成可视化图形

![demo](example/demo.png)

## 使用方法

	./ycsb2graphV2.sh [resultsDir]...
	
如

	./ycsb2graphV2.sh ../ycsb_starter/Results.cockroachDB.20160830_143458 ../ycsb_starter/Results.mysql.20160830_143501

	
## 文件名要求

对测试结果只有文件名的要求，需符合以下文件名格式，用减号分隔，以.result结尾

	dbname-workloadname-recordscount.result

如：
	CockroachDB-WorkloadA-100.result

查看全部示例，请查看[example](example)链接

示例为通过ycsb_starter提供的测试结果，关于ycsb_starter，请查看[ycsb_starter](http://192.168.100.93:3000/wenzhenglin/ycsb_starter)链接

end.