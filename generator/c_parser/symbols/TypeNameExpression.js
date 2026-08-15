class TypeNameExpression {
    constructor({
        open,
        type,
        close
    }, loc) {
        this.open = open;
        this.type = type;
        this.close = close;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.open.visit(cb, parents);
        this.type.visit(cb, parents);
        this.close.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.TypeNameExpression = TypeNameExpression;
