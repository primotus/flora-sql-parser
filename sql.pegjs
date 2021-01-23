// https://raw.githubusercontent.com/epsagon/epsagon-node/master/src/peg/sql.pegjs
{
  function debug(str) {
    console.log(str);
  }

  function createUnaryExpr(op, e) {
    return {
      location: location(), type     : 'unary_expr',
      operator : op,
      expr     : e
    }
  }

  function createBinaryExpr(op, left, right) {
    return {
      location: location(), type      : 'binary_expr',
      operator  : op,
      left      : left,
      right     : right
    }
  }

  function createList(head, tail) {
    var result = [head];
    for (var i = 0; i < tail.length; i++) {
      result.push(tail[i][3]);
    }
    return result;
  }

  function createExprList(head, tail, room) {
    var epList = createList(head, tail);
    var exprList  = [];
    var ep;
    for (var i = 0; i < epList.length; i++) {
      ep = epList[i];
      if (ep.type == 'param') {
        ep.room = room;
        ep.pos  = i;
      } else {
        exprList.push(ep);
      }
    }
    return exprList;
  }

  function createBinaryExprChain(head, tail) {
    var result = head;
    for (var i = 0; i < tail.length; i++) {
      result = createBinaryExpr(tail[i][1], result, tail[i][3]);
    }
    return result;
  }

  var reservedMap = {
    'SHOW'    : true,
    'DROP'    : true,
    'SELECT'  : true,
    'UPDATE'  : true,
    'CREATE'  : true,
    'DELETE'  : true,
    'INSERT'  : true,
    'REPLACE' : true,
    'EXPLAIN' : true,
    'ALL'     : true,
    'DISTINCT': true,
    'AS'      : true,
    'TABLE'   : true,
    'INTO'    : true,
    'FROM'    : true,
    'SET'     : true,
    'LEFT'    : true,
    'ON'      : true,
    'INNER'   : true,
    'JOIN'    : true,
    'UNION'   : true,
    'VALUES'  : true,
    'EXISTS'  : true,
    'WHERE'   : true,
    'GROUP'   : true,
    'BY'      : true,
    'HAVING'  : true,
    'ORDER'   : true,
    'ASC'     : true,
    'DESC'    : true,
    'LIMIT'   : true,
    'BETWEEN' : true,
    'IN'      : true,
    'IS'      : true,
    'LIKE'    : true,
    'CONTAINS': true,
    'NOT'     : true,
    'AND'     : true,
    'OR'      : true,
    'TRUE'    : true,
    'FALSE'   : true,
    'NULL'    : true
  }

  var cmpPrefixMap = {
    '+' : true,
    '-' : true,
    '*' : true,
    '/' : true,
    '>' : true,
    '<' : true,
    '!' : true,
    '=' : true,
    'B' : true,
    'b' : true,
    'I' : true,
    'i' : true,
    'L' : true,
    'l' : true,
    'N' : true,
    'n' : true,
    'C' : true,
    'c' : true,
  }

  var params = [];

  var varList = [];
}

start
  = __ ast:(
      union_stmt  /
      update_stmt /
      delete_stmt /
      replace_insert_stmt /
      create_table_stmt
    ) {
      ast.params = params;
      return ast;
    }
    /ast:proc_stmts {
      return ast;
    }

union_stmt
  = head:select_stmt tail:(__ KW_UNION __ select_stmt)* {
      var cur = head;
      for (var i = 0; i < tail.length; i++) {
        cur._next = tail[i][3];
        cur = cur._next
      }
      return head;
    }

create_table_stmt
 = KW_CREATE __ KW_TABLE __ (KW_IF __ KW_NOT __ KW_EXISTS __) ?
   tb: table_name __ '(' __
    clist:columns_defs
   __ ')' __ topt:table_options? __ popt:partition_options? __ ';'? __? {
    return {
      type: 'create_table',
      name: tb,
      columns: clist,
      tableOptions: topt,
      partitionOptions: popt
    }
  }

columns_defs
  = h:column_def t:(__ COMMA __ column_def)* {
    return createList(h, t);
  }

column_def
  = index_def /
    (
    n:column __
    t:column_type
    e:(__ (literal/ident_name))* {
      let ext = [];
      e.forEach((v) => {
          ext.push(v[1]);
      });
      return {
        name: n,
        type: t,
        ext: ext
      }
    }
    )

column_type
  = ct: (func_call/ident) {
    if (ct.type === 'function') {
      let args = [];
      ct.args.value.forEach((v) => {
        args.push(v.value);
      });
      return {
        type: ct.name,
        args: args
      }
    } else {
      return {type: ct}
    }
  }

 table_options
  = h:table_option t:(__ table_option)* {
    let res = h;
    t.forEach((v) => {
        let tmp = v[1];
      let keys = Object.keys(tmp)
        keys.forEach((k) => {
          res[k] = tmp[k].column;
        });
    });
    return res;
  }

 table_option
  = k:primary __ '='? __ v:primary {
    let obj = {};
    let key = k.type === 'column_ref' ? k.column : k.value;
    let value = v.type === 'column_ref' ? v.column : v.value;
    obj[key] = value;
    return obj;
  }

partition_options
 = h:primary t:(__ primary)* {
   let res = [h];
   t.forEach((v) => {
    res.push(v);
   });
   return res;
 }

index_def
 = f:$(ident_name* __ ('KEY'i/'INDEX'i)) __ n:column __ '(' l: column_clause ')'{
   let list = [];
   l.forEach((v) => {
     list.push(v.expr.column)
   });
   return {
     type: f,
     name: n,
     columns: list
   }
 }


delete_stmt
= KW_DELETE __ f:from_clause __ w:where_clause? {
  return {
    type: 'delete',
    from: f,
    where: w
  }
}

select_stmt
  =  select_stmt_nake
  / s:('(' __ select_stmt __ ')') {
      return s[2];
    }

select_stmt_nake
  = KW_SELECT           __
    d:KW_DISTINCT?      __
    c:column_clause     __
    f:from_clause?      __
    w:where_clause?     __
    g:group_by_clause?  __
    o:order_by_clause?  __
    l:limit_clause?  {
      return {
        location: location(), type      : 'select',
        distinct  : d,
        columns   : c,
        from      : f,
        where     : w,
        groupby   : g,
        orderby   : o,
        limit     : l
      }
  }

column_clause "column_clause"
  = (KW_ALL / (STAR !ident_start)) {
      return '*';
    }
  / head:column_list_item tail:(__ COMMA __ column_list_item)* {
      return createList(head, tail);
    }

column_list_item
  = e:additive_expr __ alias:alias_clause? {
      return {
        expr : e,
        as : alias
      };
    }

alias_clause
  = KW_AS? __ i:ident { return i; }

from_clause
  = KW_FROM __ l:table_ref_list { return l; }

table_ref_list
  = head:table_base
    tail:table_ref*  {
      tail.unshift(head);
      return tail;
    }

table_ref
  = __ COMMA __ t:table_base { return t; }
  / __ t:table_join { return t; }


table_join
  = op:join_op __ t:table_base __ expr:on_clause? {
    t.join = op;
    t.on   = expr;
    return t;
    /*
      return  {
        db    : t.db,
        table : t.table,
        as    : t.as,
        join  : op,
        on    : expr
      }
    */
    }

table_base
  = t:table_name __ KW_AS? __ alias:ident? {
      if (t.type == 'var') {
        t.as = alias;
        return t;
      } else {
        return  {
          db    : t.db,
          table : t.table,
          as    : alias
        }
      }
    }

join_op
  = KW_LEFT __ KW_JOIN { return 'LEFT JOIN'; }
  / (KW_INNER __)? KW_JOIN { return 'INNER JOIN'; }

table_name
  = '`'? dt:ident tail:(__ DOT __ ident_name)? '`'? {
      var obj = {
        db : '',
        table : dt
      }
      if (tail) {
        obj.db = dt;
        obj.table = tail[3];
      }
      return obj;
    }
    /v:var_decl {
      v.db = '';
      v.table = v.name;
      return v;
    }

on_clause
  = KW_ON __ e:expr { return e; }

where_clause
  = KW_WHERE __ e:expr { return e; }

group_by_clause
  = KW_GROUP __ KW_BY __ l:column_ref_list { return l; }

column_ref_list
  = head:column_ref tail:(__ COMMA __ column_ref)* {
      return createList(head, tail);
    }

having_clause
  = KW_HAVING e:expr { return e; }

order_by_clause
  = KW_ORDER __ KW_BY __ l:order_by_list { return l; }

order_by_list
  = head:order_by_element tail:(__ COMMA __ order_by_element)* {
      return createList(head, tail);
    }

order_by_element
  = e:expr __ d:(KW_DESC / KW_ASC)? {
    var obj = {
      expr : e,
      type : 'ASC'
    }
    if (d == 'DESC') {
      obj.type = 'DESC';
    }
    return obj;
  }

number_or_param
  = literal_numeric
  / param

int_or_param
  = literal_int / param

limit_clause
  = KW_LIMIT __ i1:(int_or_param) __ tail:(COMMA __ int_or_param)? {
      var res = [i1];
      if (!tail) {
        res.unshift({
          location: location(), type : 'number',
          value : 0
        });
      } else {
        res.push(tail[2]);
      }
      return res;
    }

update_stmt
  = KW_UPDATE    __
    t:table_name __
    KW_SET       __
    l:set_list   __
    w:where_clause {
      return {
        location: location(), type : 'update',
        db    : t.db,
        table : t.table,
        set   : l,
        where : w
      }
    }

set_list
  = head:set_item tail:(__ COMMA __ set_item)*  {
      return createList(head, tail);
    }

set_item
  = c:column_name __ '=' __ v:additive_expr {
      return {
        column: c,
        value : v
      }
    }

replace_insert_stmt
  = ri:replace_insert       __
    KW_INTO                 __
    t:table_name  __ LPAREN __
    c:column_list  __ RPAREN __
    v:value_clause             {
      return {
        location: location(), type      : ri,
        db        : t.db,
        table     : t.table,
        columns   : c,
        values    : v
      }
    }

replace_insert
  = KW_INSERT   { return 'insert'; }
  / KW_REPLACE  { return 'replace' }

value_clause
  = KW_VALUES __ l:value_list  { return l; }

value_list
  = head:value_item tail:(__ COMMA __ value_item)* {
      return createList(head, tail);
    }

value_item
  = LPAREN __ l:expr_list  __ RPAREN {
      return l;
    }

expr_list
  = head:expr tail:(__ COMMA __ expr)*{
      var el = {
        type : 'expr_list'
      }

      var l = createExprList(head, tail, el);

      el.value = l;
      return el;
    }

expr_list_or_empty
  = l:expr_list
  / (''{
      return {
        location: location(), type : 'expr_list',
        value : []
      }
    })

expr = or_expr

or_expr
  = head:and_expr tail:(__ KW_OR __ and_expr)* {
      return createBinaryExprChain(head, tail);
    }

and_expr
  = head:not_expr tail:(__ KW_AND __ not_expr)* {
      return createBinaryExprChain(head, tail);
    }

not_expr
  = (KW_NOT / "!" !"=") __ expr:not_expr {
      return createUnaryExpr('NOT', expr);
    }
  / comparison_expr

comparison_expr
  = left:additive_expr __ rh:comparison_op_right? {
      if (!rh) {
        return left;
      } else {
        var res = null;
        if (rh.type == 'arithmetic') {
          res = createBinaryExprChain(left, rh.tail);
        } else {
          res = createBinaryExpr(rh.op, left, rh.right);
        }
        return res;
      }
    }

comparison_op_right
  = arithmetic_op_right
    / in_op_right
    / between_op_right
    / is_op_right
    / like_op_right
    / contains_op_right

arithmetic_op_right
  = l:(__ arithmetic_comparison_operator __ additive_expr)+ {
      return {
        type : 'arithmetic',
        tail : l
      }
    }

arithmetic_comparison_operator
  = ">=" / ">" / "<=" / "<>" / "<" / "=" / "!="

is_op_right
  = op:KW_IS __ right:additive_expr {
      return {
        op    : op,
        right : right
      }
    }

between_op_right
  = op:KW_BETWEEN __  begin:additive_expr __ KW_AND __ end:additive_expr {
      return {
        op    : op,
        right : {
          type : 'expr_list',
          value : [begin, end]
        }
      }
    }

like_op
  = nk:(KW_NOT __ KW_LIKE) { return nk[0] + ' ' + nk[2]; }
  / KW_LIKE

in_op
  = nk:(KW_NOT __ KW_IN) { return nk[0] + ' ' + nk[2]; }
  / KW_IN

contains_op
  = nk:(KW_NOT __ KW_CONTAINS) { return nk[0] + ' ' + nk[2]; }
  / KW_CONTAINS

like_op_right
  = op:like_op __ right:comparison_expr {
      return {
        op    : op,
        right : right
      }
    }

in_op_right
  = op:in_op __ LPAREN  __ l:expr_list __ RPAREN {
      return {
        op    : op,
        right : l
      }
    }
  / op:in_op __ e:var_decl {
      return {
        op    : op,
        right : e
      }
    }

contains_op_right
  = op:contains_op __ LPAREN  __ l:expr_list __ RPAREN {
      return {
        op    : op,
        right : l
      }
    }
  / op:contains_op __ e:var_decl {
      return {
        op    : op,
        right : e
      }
    }

additive_expr
  = head:multiplicative_expr
    tail:(__ additive_operator  __ multiplicative_expr)* {
      return createBinaryExprChain(head, tail);
    }

additive_operator
  = "+" / "-"

multiplicative_expr
  = head:primary
    tail:(__ multiplicative_operator  __ primary)* {
      return createBinaryExprChain(head, tail)
    }

multiplicative_operator
  = "*" / "/" / "%"

primary
  = literal
  / aggr_func
  / func_call
  / column_ref
  / param
  / LPAREN __ e:expr __ RPAREN {
      e.paren = true;
      return e;
    }
  / var_decl

column_ref
  = tbl:ident __ DOT __ col:column {
      return {
        location: location(), type : 'column_ref',
        table : tbl,
        column : col
      };
    }
  / col:column {
      return {
        location: location(), type : 'column_ref',
        table : '',
        column: col
      };
    }

column_list
  = head:column tail:(__ COMMA __ column)* {
      return createList(head, tail);
    }

ident =
  name:ident_name !{ return reservedMap[name.toUpperCase()] === true; } {
    return name;
  }

column =
  name:column_name !{ return reservedMap[name.toUpperCase()] === true; } {
    return name;
  }
  /'\"' chars:[^"]+ '\"' {
    return chars.join('');
  }

column_name
  =  start:ident_start parts:column_part* { return start + parts.join(''); }

ident_name
  =  start:ident_start parts:ident_part* { return start + parts.join(''); }

ident_start = [A-Za-z_]

ident_part  = [A-Za-z0-9_]

column_part  = [A-Za-z0-9_:]


param "PARAM[:param, ?]"
  = l:(':' ident_name) / l:('?') {
    var p = {
      type : 'param',
      value: l.length > 1 ? l[1] : l[0]
    };
    params.push(p);
    return p;
  }

aggr_func
  = aggr_fun_count
  / aggr_fun_smma

aggr_fun_smma
  = name:KW_SUM_MAX_MIN_AVG  __ LPAREN __ e:additive_expr __ RPAREN {
      return {
        type : 'aggr_func',
        name : name,
        args : {
          expr : e
        }
      }
    }

KW_SUM_MAX_MIN_AVG
  = w:[0-9a-zA-Z_]+{return w.join('');}

aggr_fun_count
  = name:KW_COUNT __ LPAREN __ arg:count_arg __ RPAREN {
      return {
        type : 'aggr_func',
        name : name,
        args : arg
      }
    }

count_arg
  = e:star_expr {
      return {
        expr  : e
      }
    }
  / d:KW_DISTINCT? __ c:column_ref {
      return {
        distinct : d,
        expr   : c
      }
    }

star_expr
  = "*" {
      return {
        location: location(), type : 'star',
        value : '*'
      }
    }

func_call
  = name:ident __ LPAREN __ l:expr_list_or_empty __ RPAREN {
      return {
        type : 'function',
        name : name,
        args : l
      }
    }

literal
  = literal_string / literal_numeric / literal_bool /literal_null

literal_list
  = head:literal tail:(__ COMMA __ literal)* {
      return createList(head, tail);
    }

literal_null
  = KW_NULL {
      return {
        location: location(), type : 'null',
        value : null
      };
    }

literal_bool
  = KW_TRUE {
      return {
        location: location(), type : 'bool',
        value : true
      };
    }
  / KW_FALSE {
      return {
        location: location(), type : 'bool',
        value : false
      };
    }

literal_string
  = ca:( ("'" single_char* "'")) {
      return {
        location: location(), type : 'string',
        value : ca[1].join('')
      }
    }

single_char
  = [^'\\\0-\x1F\x7f]
  / escape_char

double_char
  = [^"\\\0-\x1F\x7f]
  / escape_char

escape_char
  = "\\'"  { return "'";  }
  / '\\"'  { return '"';  }
  / "\\\\" { return "\\"; }
  / "\\/"  { return "/";  }
  / "\\b"  { return "\b"; }
  / "\\f"  { return "\f"; }
  / "\\n"  { return "\n"; }
  / "\\r"  { return "\r"; }
  / "\\t"  { return "\t"; }
  / "\\u" h1:hexDigit h2:hexDigit h3:hexDigit h4:hexDigit {
      return String.fromCharCode(parseInt("0x" + h1 + h2 + h3 + h4));
    }

line_terminator
  = [\n\r]

literal_numeric
  = n:number {
      return {
        location: location(), type : 'number',
        value : n
      }
    }
literal_int "LITERAL INT"
  = n:int {
    return {
      type: 'number',
      value: n
    }
  }

number
  = int_:int frac:frac exp:exp __ { var x = parseFloat(int_ + frac + exp); return (x % 1 != 0) ? x.toString() : x.toString() + ".0"}
  / int_:int frac:frac __         { var x = parseFloat(int_ + frac); return (x % 1 != 0) ? x.toString() : x.toString() + ".0"}
  / int_:int exp:exp __           { return parseFloat(int_ + exp).toString(); }
  / int_:int __                   { return parseFloat(int_).toString(); }

int
  = digit19:digit19 digits:digits     { return digit19 + digits;       }
  / digit:digit
  / op:("-" / "+" ) digit19:digit19 digits:digits { return "-" + digit19 + digits; }
  / op:("-" / "+" ) digit:digit                   { return "-" + digit;            }

frac
  = "." digits:digits { return "." + digits; }

exp
  = e:e digits:digits { return e + digits; }

digits
  = digits:digit+ { return digits.join(""); }

digit "NUMBER"  = [0-9]
digit19 "NUMBER" = [1-9]

hexDigit "HEX"
  = [0-9a-fA-F]

e
  = e:[eE] sign:[+-]? { return e + sign; }


KW_NULL     = "NULL"i     !ident_start
KW_TRUE     = "TRUE"i     !ident_start
KW_FALSE    = "FALSE"i    !ident_start

KW_SHOW     = "SHOW"i     !ident_start
KW_DROP     = "DROP"i     !ident_start
KW_SELECT   = "SELECT"i   !ident_start
KW_UPDATE   = "UPDATE"i   !ident_start
KW_CREATE   = "CREATE"i   !ident_start
KW_DELETE   = "DELETE"i   !ident_start
KW_INSERT   = "INSERT"i   !ident_start
KW_REPLACE  = "REPLACE"i  !ident_start
KW_EXPLAIN  = "EXPLAIN"i  !ident_start

KW_INTO     = "INTO"i     !ident_start
KW_FROM     = "FROM"i     !ident_start
KW_SET      = "SET"i      !ident_start

KW_AS       = "AS"i       !ident_start
KW_TABLE    = "TABLE"i    !ident_start

KW_ON       = "ON"i       !ident_start
KW_LEFT     = "LEFT"i     !ident_start
KW_INNER    = "INNER"i    !ident_start
KW_JOIN     = "JOIN"i     !ident_start
KW_UNION    = "UNION"i    !ident_start
KW_VALUES   = "VALUES"i   !ident_start

KW_IF       = "IF"i       !ident_start
KW_EXISTS   = "EXISTS"i   !ident_start

KW_WHERE    = "WHERE"i    !ident_start

KW_GROUP    = "GROUP"i    !ident_start
KW_BY       = "BY"i       !ident_start
KW_ORDER    = "ORDER"i    !ident_start
KW_HAVING   = "HAVING"i   !ident_start

KW_LIMIT    = "LIMIT"i    !ident_start

KW_ASC      = "ASC"i      !ident_start    { return 'ASC';     }
KW_DESC     = "DESC"i     !ident_start    { return 'DESC';    }

KW_ALL      = "ALL"i      !ident_start    { return 'ALL';     }
KW_DISTINCT = "DISTINCT"i !ident_start    { return 'DISTINCT';}

KW_BETWEEN  = "BETWEEN"i  !ident_start    { return 'BETWEEN'; }
KW_IN       = "IN"i       !ident_start    { return 'IN';      }
KW_IS       = "IS"i       !ident_start    { return 'IS';      }
KW_LIKE     = "LIKE"i     !ident_start    { return 'LIKE';    }
KW_CONTAINS = "CONTAINS"i !ident_start    { return 'CONTAINS';}

KW_NOT      = "NOT"i      !ident_start    { return 'NOT';     }
KW_AND      = "AND"i      !ident_start    { return 'AND';     }
KW_OR       = "OR"i       !ident_start    { return 'OR';      }

KW_COUNT    = "COUNT"i    !ident_start    { return 'COUNT';   }
KW_MAX      = "MAX"i      !ident_start    { return 'MAX';     }
KW_MIN      = "MIN"i      !ident_start    { return 'MIN';     }
KW_SUM      = "SUM"i      !ident_start    { return 'SUM';     }
KW_AVG      = "AVG"i      !ident_start    { return 'AVG';     }

DOT       = '.'
COMMA     = ','
STAR      = '*'
LPAREN    = '('
RPAREN    = ')'

LBRAKE    = '['
RBRAKE    = ']'

__ =
  whitespace*

char = .

whitespace 'WHITE_SPACE' = [ \t\n\r]

EOL "EOF"
  = EOF
  / [\n\r]+

EOF = !.

proc_stmts
  = proc_stmt*

proc_stmt
  = &proc_init __ s:(assign_stmt / return_stmt) {
      return {
        stmt : s,
        vars: varList
      }
    }

proc_init  = '' { varList = []; return true; }

assign_stmt
  = va:var_decl __ KW_ASSIGN __ e:proc_expr {
    return {
      type : 'assign',
      left : va,
      right: e
    }
  }

return_stmt
  = KW_RETURN __ e:proc_expr {
  return {
    type : 'return',
    expr: e
  }
}

proc_expr
  = select_stmt
  / proc_join
  / proc_additive_expr
  / proc_array

proc_additive_expr
  = head:proc_multiplicative_expr
    tail:(__ additive_operator  __ proc_multiplicative_expr)* {
      return createBinaryExprChain(head, tail);
    }

proc_multiplicative_expr
  = head:proc_primary
    tail:(__ multiplicative_operator  __ proc_primary)* {
      return createBinaryExprChain(head, tail);
    }

proc_join
  = lt:var_decl __ op:join_op  __ rt:var_decl __ expr:on_clause {
      return {
        type    : 'join',
        ltable  : lt,
        rtable  : rt,
        op      : op,
        on      : expr
      }
    }

proc_primary
  = literal
  / var_decl
  / proc_func_call
  / param
  / LPAREN __ e:proc_additive_expr __ RPAREN {
      e.paren = true;
      return e;
    }

proc_func_call
  = name:ident __ LPAREN __ l:proc_primary_list __ RPAREN {
      return {
        type : 'function',
        name : name,
        args : {
          location: location(), type : 'expr_list',
          value : l
        }
      }
    }

proc_primary_list
  = head:proc_primary tail:(__ COMMA __ proc_primary)* {
      return createList(head, tail);
    }

proc_array =
  LBRAKE __ l:proc_primary_list __ RBRAKE {
    return {
      type : 'array',
      value : l
    }
  }


var_decl
  = KW_VAR_PRE name:ident_name m:mem_chain {
    varList.push(name);
    return {
      type : 'var',
      name : name,
      members : m
    }
  }

mem_chain
  = l:('.' ident_name)* {
    var s = [];
    for (var i = 0; i < l.length; i++) {
      s.push(l[i][1]);
    }
    return s;
  }

 KW_VAR_PRE = '$'

 KW_RETURN = 'return'i

 KW_ASSIGN = ':='
