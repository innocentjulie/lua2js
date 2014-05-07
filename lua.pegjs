{
  function loc() { return {start: { line: line(), column: column() } } }
  function range() { return [offset(), offset() + text().length]; }
  function listHelper(a,b,c) { return [a].concat(b.map(function(b) { return b[c || 2]; })); }
}

start = ws? t:BlockStatement ws? { return t; }

ws = ([ \r\t\n] / ("--" ( [^\n]* "\n" / .* ) )) +

BlockStatement =
    r:ReturnStatement
    { return {
        type: "BlockStatement",
        body: [r]
    } } /
    list:StatatementList ret:(ws ReturnStatement)?
    { return {
        type: "BlockStatement",
        body: ret === null ? list : list.concat([ret[1]])
    } } 
 

StatatementList = 
    a:Statement? b:( ( ws? ";" ws? / ws )+ Statement )*
    {  
        if ( a === null ) return [];
        if ( b === null ) return a;
        return listHelper(a,b,1);
    }

ReservedWord = "if" / "then" / "else" / "do" / "end" / "return" / "local" /
    "function" / "not" / "break" / "for" / "until" / "function" / binop / unop

Name = !(ReservedWord (ws / !.)) a:$([a-zA-Z_][a-zA-Z0-9_]*) { return a; }
Number = $([0-9]+("." [0-9]+)?)

stringchar =
    "\\" c:[abfrntv'"] { return {
        "n": "\n",
        "b": "\b",
        "f": "\f",
        "r": "\r",
        "t": "\t",
        "v": "\v",
        '"': '"',
        "'": "'" 
    }[c] } / 
    "\\\n" { return "" } /
    "\\\z" ws { return "" } /
    "\\" a:$[0-9] b:$[0-9]? c:$[0-9]? { return String.fromCharCode(parseInt('' + a + b + c)); } /
    "\\" { error('Invalid Escape Sequence') } / 
    $[^'"'] 

String =
    "\"" r:(stringchar/"'") * "\"" { return r.join(''); } /
    "'" r:(stringchar/'"') * "'" { return r.join(''); }

Statement = 
    s: ( 
    BreakStatement /
    NumericFor /
    WhileStatement /
    IfStatement /
    ExpressionStatement / 
    DoEndGrouped /
    LocalAssingment /
    FunctionDeclaration /
    LocalFunction / $"" & (ws? ";")
    ) {  return s == "" ? { type:"EmptyStatement" } : s; }

DoEndGrouped = "do" b:BlockStatement "end" { return b }

NumericFor =
    "for" ws a:Identifier ws? "=" ws? b:Expression ws? "," ws? c:Expression d:( ws? "," Expression )? ws? "do" ws? body:BlockStatement ws? "end"
    {
        var amount = d == null ? {type: "Literal", value: 1 } : d[2];

        var update = {
            type: "AssignmentExpression",
            left: a,
            right: {type: "BinaryExpression", left: a, right: amount, operator: "+" },
            operator: "=",
            loc: loc(),
            range: range()
        };

        var out = {
            type: "ForStatement",
            init: {
                type: "VariableDeclaration",
                declarations: [
                    {
                        type: "VariableDeclarator",
                        id: a,
                        init: b,
                    }
                ],
                operator: "=",
                kind: "var"
            },
            body: body,
            update: update,
            test: {
                type: "BinaryExpression",
                left: a,
                right: c,
                operator: "<="
            },
            loc: loc(),
            range: range()
        };

        return out;
    }

LocalAssingment =
    "local" ws expr:AssignmentExpression
    { return {
        type: "VariableDeclaration",
        declarations: [
            {
                type: "VariableDeclarator",
                id: expr.left,
                init: expr.right,
            }
        ],
        operator: "=",
        kind: "var",
        loc: loc(),
        range: range()
    } }

AssignmentExpression =
    left:var ws? "=" ws? right:Expression
    { return {
        type: "AssignmentExpression",
        left: left,
        right: right,
        operator: "=",
        loc: loc(),
        range: range()
    } }

BreakStatement = 
    "break"
    { return {
        "type": "BreakStatement",
        loc: loc(),
        range: range()
    } }

ExpressionStatement =
    e:(AssignmentExpression/CallExpression)
    { return {
        type: "ExpressionStatement",
        expression: e,
        loc: loc(),
        range: range()
    } }


IfStatement =
    "if" ws test:Expression ws "then" ws then:BlockStatement elze:( ws? "else" ws BlockStatement )? ws? "end" 
    {
        var result = { type: "IfStatement", test: test, consequent: then, loc: loc(), range: range()}
        if ( elze !== null ) result.alternate = elze[3];
        return result;
    }

ReturnStatement = 
    "return" ws argument:explist
    { 
        var arg;
        if ( argument.length == 1 ) arg = argument[0];
        else if ( argument.length > 1 ) arg = {
            type: "ArrayExpression",
            elements: argument
        };

        return {
            type: "ReturnStatement",
            argument: arg,
            loc: loc(),
            range: range()
        }
    } 

WhileStatement =
    "while" ws test:Expression ws "do" ws body:BlockStatement ws "end" 
    { return {
        type: "WhileStatement",
        test: test,
        body: body,
        loc: loc(),
        range: range()

    } }




SimpleExpression = (
    FunctionExpression / CallExpression / Identifier /
    ObjectExpression / UnaryExpression / Literal / ParenExpr )

Expression = 
    FunctionExpression / CallExpression / a:(MemberExpression/SimpleExpression/var) b:( ws? op:binop ws? Expression )?
    {
        if ( b === null ) return a;
        var xop = b[1];
        if ( xop == "~=" ) xop = "!=";
        else if ( xop == ".." ) xop = "+";
        else if ( xop == "or" ) xop = "||";
        else if ( xop == "and" ) xop = "&&";

        return {
            type: "BinaryExpression",
            left: a,
            right: b[3],
            operator: xop,
            loc: loc(),
            range: range()
        };
    } / AssignmentExpression



unop = $("-" / "not" / "#")
binop = $("+" / "-" / "==" / ">" / "<" / "~=" / ".." / "and" / "or" / "*" / "/" / "%" )


prefixexp =
    funcname / '(' ws? e:Expression ws? ')' { return e; }

CallExpression = 
    who:prefixexp ws? a:args 
    { return {
        type: "CallExpression",
        callee: who,
        arguments: a,
        loc: loc(),
        range: range()
    } } /
    who:prefixexp ws? b:ObjectExpression 
    { return {
        type: "CallExpression",
        callee: who,
        arguments: [b],
        loc: loc(),
        range: range()
    } } /
    who:prefixexp ws? c:String
    { return {
        type: "CallExpression",
        callee: who,
        arguments: [{type: "Literal", value: c}],
        loc: loc(),
        range: range()
    } } 

ParenExpr = "(" ws? a:Expression ws? ")" { return a; }


funcname =
    a:Identifier b:(ws? [.:] ws? Identifier)*
    {
        if ( b.length == 0 ) return a;
        var left = a;
        for ( var i in b ) {
            left = {
                type: "MemberExpression",
                object: left,
                property: b[i][3],
                computed: false,
                loc:loc(),
                range:range()
            }
        }
        return left;
    }

explist = 
    a:Expression b:(ws? "," ws? e:Expression)*
    {
         return listHelper(a,b,3); 
    } 

args =
    "(" ws? a:explist ")"
    {
         return a; 
    } /
    "(" ws? ")"
    {
        return []
    }

var = MemberExpression / Identifier

MemberExpression = 
    a:SimpleExpression "[" ws? b:Expression ws? "]"
    { return {
        type: "MemberExpression",
        object: a,
        property:b,
        computed:true,
        loc:loc(),
        range: range()
    } } /
    a:SimpleExpression "." b:SimpleExpression
    { return {
        type: "MemberExpression",
        object: a,
        property:b,
        computed:false,
        loc:loc(),
        range:range()
    } }
    


ObjectExpression =
    "{" ws? f:field? s:(ws? ("," / ";") ws? field)* ws? "}" 
    { 
        var result = {
            type: "ObjectExpression",
            properties: [],
            loc: loc(),
            range: range()
        };

        if ( f != null ) {
            if ( f.key === undefined ) f.key = {type: "Literal", value: 1};
            result.properties.push(f);
        }
        
        if ( s != null )
        for ( var idx in s ) {
            var v = s[idx][3];
            if ( v.key === undefined ) v.key = {type: "Literal", value: 2 + parseInt(idx)};
            result.properties.push(v);
        }

        return result;
    }

field =
    n:(Literal/Identifier) ws? "=" ws? v:Expression 
    {
        return { key: n, value: v };
    }/
    v:Expression ws?
    {
        return { value: v };
    }/
    ws? "[" ws? k:Expression ws? "]" ws? "=" ws? v:Expression
    {
        return { key: k, value: v }; 
    }/


FunctionDeclaration =
    "function" ws? name:funcname ws? f:funcbody
    {
        return {
            type: "FunctionDeclaration",
            id: name,
            params: f.params,
            body: f.body
        }
    }

LocalFunction =
    "local" ws "function" ws? name:funcname ws? f:funcbody
    {
        return {
            type: "FunctionDeclaration",
            id: name,
            params: f.params,
            body: f.body
        }
    }

FunctionExpression = 
    f:funcdef 
    {
        var result = {
            type: "FunctionExpression",
            body: f.body,
            params: f.params,
            loc:loc(),
            range:range()
        }

        return result;

    }

funcdef = 
    "function" ws? b:funcbody { return b; }

funcbody = 
    "(" ws? p:paramlist ws? ")" ws? body:BlockStatement ws? "end"
    {
        return { params: p, body: body }
    }

paramlist = 
    a:Identifier ws? b:("," ws? Identifier)*
    {
        return listHelper(a,b); 
    } /
    ws? { 
        return [] 
    }


UnaryExpression =
    o:unop ws? e:Expression
    { 
        var ops = {"not": "!", "-": "-", "#": "#" }
        return { 
            type: "UnaryExpression",
            operator: ops[o],
            argument: e,
            prefix: true,
            loc: loc(),
            range: range()
        }
    }

Identifier =
    name:Name
    { return {
        type: "Identifier",
        name: name,
        loc: loc(),
        range: range()
    } }

Literal = 
    a: ("nil" / "false" / "true") 
    {
        var values = {"nil": null, "false": false, "true": true} 
        return { type: "Literal", value: values[a], loc: loc(), range: range() }

    } / 
    b: Number [eE] c:$(("-" / "+")? [0-9]+)
    {
        return { type: "Literal", value: parseFloat(b) * Math.pow(10, parseInt(c)), loc: loc(), range: range()  }

    } /
    b: Number
    {
        return { type: "Literal", value: parseFloat(b), loc: loc(), range: range()  }

    } /
    s: String
    {
        return { type: "Literal", value: s, loc: loc(), range: range()  }

    } 