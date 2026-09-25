const String updateUrlGithub =
    'https://api.github.com/repos/Weiyi122332/OASX/releases/latest';

const String readmeUrlGithub =
    'https://api.github.com/repos/runhey/OnmyojiAutoScript/readme';

const String oasxRelease = "https://github.com/Weiyi122332/OASX/releases";

// 任务组任务列表的参数类型：界面上是可以新增、拖动改顺序的列表
// （OAS 那边由任务组的 x-ui-type 标出来）。
const String taskListArgumentType = 'task_list';

// 值是一份列表的参数类型，回写服务端时要编码成 JSON 数组。
const Set<String> listArgumentTypes = {'multi_enum', taskListArgumentType};
