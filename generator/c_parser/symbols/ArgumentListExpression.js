class ArgumentListExpression {
    constructor({
        open,
        args,
        close
    }, loc) {
        this.open = open;
        this.args = args;
        this.close = close;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.open.visit(cb, parents);

        for (const arg of this.args) {
            arg.visit(cb, parents);
        }

        this.close.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.ArgumentListExpression = ArgumentListExpression;
